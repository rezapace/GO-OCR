package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/tiagomelo/go-ocr/ocr"
)

type PageData struct {
	ExtractedText string
	Error         string
	FileName      string
}

type OCRRequest struct {
	ImageBytes []byte
	Filename   string
	ResponseCh chan OCRResponse
}

type OCRResponse struct {
	Text string
	Err  error
}

var (
	ocrClient      ocr.Ocr
	ocrMutex       sync.RWMutex
	bufferPool     sync.Pool
	templateCache  map[string]*template.Template
	templateMutex  sync.RWMutex
	ocrWorkerPool  chan OCRRequest
	tesseractPath  string
	tesseractFound bool
	initOnce       sync.Once
)

// Buffer pool for efficient memory reuse
func init() {
	bufferPool = sync.Pool{
		New: func() interface{} {
			return make([]byte, 0, 1024*1024) // 1MB initial capacity
		},
	}

	// Initialize template cache
	templateCache = make(map[string]*template.Template)

	// Initialize OCR worker pool with 3 workers for concurrent processing
	ocrWorkerPool = make(chan OCRRequest, 10)
	for i := 0; i < 3; i++ {
		go ocrWorker()
	}
}

// findAvailablePort mencari port yang tersedia dari daftar port yang diberikan
func findAvailablePort(ports []int) (int, error) {
	for _, port := range ports {
		addr := ":" + strconv.Itoa(port)
		listener, err := net.Listen("tcp", addr)
		if err == nil {
			listener.Close()
			return port, nil
		}
	}
	return 0, fmt.Errorf("tidak ada port yang tersedia dari daftar: %v", ports)
}

func main() {
	// Initialize OCR once
	initOnce.Do(initOCR)

	// Pre-compile templates for better performance
	precompileTemplates()

	// Daftar port yang akan dicoba secara berurutan
	preferredPorts := []int{9000, 8000, 7000}
	
	// Cari port yang tersedia
	port, err := findAvailablePort(preferredPorts)
	if err != nil {
		log.Fatalf("❌ Error: %v", err)
	}

	// Configure server with optimized settings
	server := &http.Server{
		Addr:         ":" + strconv.Itoa(port),
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/upload", uploadHandler)
	http.HandleFunc("/setup", setupHandler)

	fmt.Printf("🚀 Server berhasil dimulai pada http://localhost:%d\n", port)
	fmt.Printf("📋 Port yang dicoba: %v\n", preferredPorts)
	fmt.Printf("✅ Menggunakan port: %d\n", port)
	
	if tesseractFound && ocrClient != nil {
		fmt.Println("✅ Menggunakan mesin OCR Tesseract untuk pengenalan teks")
		fmt.Printf("📊 OCR Worker Pool: %d workers siap\n", 3)
	} else {
		fmt.Printf("⚠️  Tesseract OCR belum dikonfigurasi. Silakan kunjungi http://localhost:%d/setup untuk petunjuk\n", port)
	}

	log.Fatal(server.ListenAndServe())
}

func checkTesseractInstallation() (string, bool) {
	// Cache check result to avoid repeated system calls
	if tesseractPath != "" {
		return tesseractPath, tesseractFound
	}

	// Common Tesseract executable names
	paths := []string{"tesseract"}

	// Add OS-specific paths
	if runtime.GOOS == "windows" {
		paths = append(paths,
			"tesseract.exe",
			"C:/Program Files/Tesseract-OCR/tesseract.exe",
			"C:/Program Files (x86)/Tesseract-OCR/tesseract.exe",
		)
	} else {
		paths = append(paths,
			"/usr/bin/tesseract",
			"/usr/local/bin/tesseract",
			"/opt/homebrew/bin/tesseract",
		)
	}

	// Check each path with timeout
	for _, path := range paths {
		if _, err := exec.LookPath(path); err == nil {
			// Verify it works with timeout
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			cmd := exec.CommandContext(ctx, path, "--version")
			if err := cmd.Run(); err == nil {
				log.Printf("✅ Found Tesseract at: %s", path)
				tesseractPath = path
				tesseractFound = true
				cancel()
				return path, true
			}
			cancel()
		}
	}

	tesseractFound = false
	return "", false
}

func initOCR() {
	path, found := checkTesseractInstallation()

	if !found {
		log.Printf("⚠️  Tesseract OCR tidak ditemukan di system PATH")
		log.Printf("Silakan install Tesseract OCR atau kunjungi halaman setup untuk petunjuk")
		return
	}

	var err error
	if path == "tesseract" {
		ocrClient, err = ocr.New()
	} else {
		ocrClient, err = ocr.New(ocr.TesseractPath(path))
	}

	if err != nil {
		log.Printf("❌ Inisialisasi OCR client gagal: %v", err)
		log.Printf("Kunjungi halaman setup untuk bantuan")
		ocrClient = nil
		tesseractFound = false
	} else {
		log.Printf("✅ OCR client berhasil diinisialisasi dengan Tesseract")
	}
}

// OCR Worker for concurrent processing
func ocrWorker() {
	for req := range ocrWorkerPool {
		result := processOCRRequest(req.ImageBytes, req.Filename)
		req.ResponseCh <- result
	}
}

func processOCRRequest(imageBytes []byte, filename string) OCRResponse {
	if ocrClient == nil {
		return OCRResponse{
			Text: "",
			Err:  fmt.Errorf("Tesseract OCR not initialized"),
		}
	}

	// Create unique temporary file name with timestamp
	tempFile := fmt.Sprintf("temp_%d_%s", time.Now().UnixNano(), filename)

	// Write bytes to temporary file efficiently
	if err := writeImageFileOptimized(tempFile, imageBytes); err != nil {
		return OCRResponse{
			Text: "",
			Err:  fmt.Errorf("failed to create temporary file: %v", err),
		}
	}

	// Clean up temporary file
	defer func() {
		if err := os.Remove(tempFile); err != nil {
			log.Printf("Warning: failed to remove temporary file %s: %v", tempFile, err)
		}
	}()

	// Perform OCR with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Create a channel for OCR result
	resultCh := make(chan OCRResponse, 1)

	go func() {
		ocrMutex.RLock()
		text, err := ocrClient.TextFromImageFile(tempFile)
		ocrMutex.RUnlock()

		if err != nil {
			resultCh <- OCRResponse{
				Text: "",
				Err:  fmt.Errorf("Tesseract OCR processing failed: %v", err),
			}
			return
		}

		// Clean up the text
		text = strings.TrimSpace(text)
		if text == "" {
			text = "No text detected in the image."
		}

		resultCh <- OCRResponse{Text: text, Err: nil}
	}()

	// Wait for result or timeout
	select {
	case result := <-resultCh:
		return result
	case <-ctx.Done():
		return OCRResponse{
			Text: "",
			Err:  fmt.Errorf("OCR processing timeout"),
		}
	}
}

// Optimized file writing with buffer reuse
func writeImageFileOptimized(filename string, data []byte) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	// Use buffered writer for better performance
	writer := io.Writer(file)
	if len(data) > 32*1024 { // Use buffer for larger files
		buf := bufferPool.Get().([]byte)
		defer bufferPool.Put(buf[:0])

		bufferedWriter := &bytes.Buffer{}
		bufferedWriter.Write(data)
		_, err = bufferedWriter.WriteTo(writer)
	} else {
		_, err = writer.Write(data)
	}

	return err
}

// Template precompilation for faster rendering
func precompileTemplates() {
	templateMutex.Lock()
	defer templateMutex.Unlock()

	// Precompile setup template
	setupTmpl := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>OCR Simple - Setup Instructions</title>
    <style>
        * { box-sizing: border-box; }
        body { font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5; margin: 0; line-height: 1.6; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
        h2 { color: #007bff; margin-top: 30px; }
        .step { background: #f8f9fa; padding: 15px; margin: 15px 0; border-left: 4px solid #007bff; border-radius: 4px; }
        .step-number { background: #007bff; color: white; border-radius: 50%; padding: 5px 10px; margin-right: 10px; font-weight: bold; }
        .download-link { background: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 0; }
        .download-link:hover { background: #0056b3; }
        .code { background: #f4f4f4; padding: 10px; border-radius: 4px; font-family: monospace; margin: 10px 0; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 15px; border-radius: 4px; margin: 15px 0; }
        .success { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 15px; border-radius: 4px; margin: 15px 0; }
        ul { margin-left: 20px; }
        li { margin: 5px 0; }
        .platform { background: #e9ecef; padding: 10px; margin: 10px 0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 OCR Simple - Setup Instructions</h1>
        
        <div class="warning">
            <strong>⚠️ Tesseract OCR Engine Not Found</strong><br>
            To use this OCR application, you need to install Tesseract OCR on your system.
        </div>

        <h2>📥 Installation Instructions</h2>

        <div class="platform">
            <h3>🍎 macOS</h3>
            <div class="step">
                <span class="step-number">1</span>
                <strong>Install using Homebrew (Recommended):</strong>
                <div class="code">brew install tesseract</div>
                <br>
                <strong>Or install with additional language packs:</strong>
                <div class="code">brew install tesseract tesseract-lang</div>
            </div>
        </div>

        <div class="platform">
            <h3>🐧 Linux (Ubuntu/Debian)</h3>
            <div class="step">
                <span class="step-number">1</span>
                <strong>Install Tesseract:</strong>
                <div class="code">sudo apt update<br>sudo apt install tesseract-ocr</div>
                <br>
                <strong>Install additional languages (optional):</strong>
                <div class="code">sudo apt install tesseract-ocr-ind tesseract-ocr-eng</div>
            </div>
        </div>

        <div class="platform">
            <h3>🐧 Linux (CentOS/RHEL/Fedora)</h3>
            <div class="step">
                <span class="step-number">1</span>
                <strong>Install Tesseract:</strong>
                <div class="code">sudo dnf install tesseract</div>
                <strong>or for older versions:</strong>
                <div class="code">sudo yum install tesseract</div>
            </div>
        </div>

        <div class="platform">
            <h3>🪟 Windows</h3>
            <div class="step">
                <span class="step-number">1</span>
                <strong>Download and install Tesseract:</strong>
                <br><br>
                <a href="https://github.com/UB-Mannheim/tesseract/wiki" class="download-link" target="_blank">
                    📦 Download Tesseract for Windows
                </a>
                <br><br>
                <strong>Installation tips:</strong>
                <ul>
                    <li>Download the latest installer from the UB-Mannheim repository</li>
                    <li>Run the installer as Administrator</li>
                    <li>Make sure to check "Add to PATH" during installation</li>
                    <li>Restart your command prompt after installation</li>
                </ul>
            </div>
        </div>

        <h2>🔧 Verification Steps</h2>
        <div class="step">
            <span class="step-number">2</span>
            <strong>Verify the installation:</strong>
            <br><br>
            <p>Open a terminal/command prompt and run:</p>
            <div class="code">tesseract --version</div>
            <br>
            <p>You should see version information if Tesseract is properly installed.</p>
        </div>

        <h2>🎯 Test the Setup</h2>
        <div class="step">
            <span class="step-number">3</span>
            <strong>Restart the OCR application and test:</strong>
            <br><br>
            <ol>
                <li>Stop the current server (Ctrl+C in terminal)</li>
                <li>Run the application again: <code>./ocr-app</code> or <code>go run main.go</code></li>
                <li>Look for the success message: "✅ Using Tesseract OCR engine for text recognition"</li>
                <li>Visit <a href="/">the main page</a> to test OCR functionality</li>
            </ol>
        </div>

        <h2>🌍 Language Support</h2>
        <div class="step">
            <strong>Tesseract supports many languages:</strong>
            <br><br>
            <p><strong>Default:</strong> English (eng)</p>
            <p><strong>Additional languages you can install:</strong></p>
            <ul>
                <li><strong>Indonesian:</strong> tesseract-ocr-ind</li>
                <li><strong>Chinese:</strong> tesseract-ocr-chi-sim (Simplified), tesseract-ocr-chi-tra (Traditional)</li>
                <li><strong>Japanese:</strong> tesseract-ocr-jpn</li>
                <li><strong>Korean:</strong> tesseract-ocr-kor</li>
                <li><strong>Arabic:</strong> tesseract-ocr-ara</li>
                <li>And many more...</li>
            </ul>
        </div>

        <h2>🚨 Troubleshooting</h2>
        <div class="step">
            <strong>Common issues and solutions:</strong>
            <br><br>
            <strong>❌ "tesseract: command not found":</strong>
            <ul>
                <li>Make sure Tesseract is installed correctly</li>
                <li>Check if it's added to your system PATH</li>
                <li>Restart your terminal/command prompt</li>
                <li>On Windows, make sure you checked "Add to PATH" during installation</li>
            </ul>
            <br>
            <strong>❌ Poor OCR accuracy:</strong>
            <ul>
                <li>Use high-resolution, clear images</li>
                <li>Ensure good contrast between text and background</li>
                <li>Try different image formats (PNG usually works best)</li>
                <li>Install additional language packs if needed</li>
            </ul>
            <br>
            <strong>❌ Application starts but OCR fails:</strong>
            <ul>
                <li>Check if the uploaded image format is supported</li>
                <li>Verify Tesseract permissions</li>
                <li>Check server logs for detailed error messages</li>
            </ul>
        </div>

        <div class="success">
            <strong>✅ Easy Setup!</strong><br>
            Unlike PaddleOCR, Tesseract is much easier to install and configure. Most package managers 
            include it, and it's widely supported across all operating systems.
        </div>

        <p style="text-align: center; margin-top: 30px;">
            <a href="/" style="background: #28a745; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">
                🏠 Back to Main Page
            </a>
        </p>
    </div>
</body>
</html>`

	var err error
	templateCache["setup"], err = template.New("setup").Parse(setupTmpl)
	if err != nil {
		log.Printf("Error precompiling setup template: %v", err)
	}

	// Precompile home template
	homeTmpl := `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>OCR Simple - Tesseract OCR</title>
    <style>
        * { box-sizing: border-box; }
        body { font-family: Arial, sans-serif; padding: 15px; background: #f5f5f5; margin: 0; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 12px; border-radius: 4px; height: 88vh; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 15px; }
        .header h1 { margin: 0 0 5px 0; font-size: 1.5em; color: #333; }
        .header .subtitle { color: #666; font-size: 0.9em; margin: 0; }
        .setup-warning { background: #fff3cd; border: 1px solid #ffeaa7; color: #856404; padding: 10px; border-radius: 4px; margin-bottom: 15px; text-align: center; }
        .setup-warning a { color: #856404; text-decoration: underline; }
        .side-by-side { display: flex; gap: 15px; height: calc(100% - 80px); }
        .left-panel, .right-panel { flex: 1; display: flex; flex-direction: column; }
        .image-preview { max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 3px; object-fit: contain; will-change: transform; }
        h3 { margin: 0 0 8px 0; font-size: 1.1em; }
        .upload-area { border: 2px dashed #ccc; padding: 25px; text-align: center; margin-bottom: 8px; border-radius: 4px; flex-grow: 1; display: flex; align-items: center; justify-content: center; flex-direction: column; transition: border-color 0.2s; }
        .upload-area.dragover { border-color: #007bff; background: #f8f9fa; }
        .btn { background: #007bff; color: white; border: none; padding: 6px 12px; border-radius: 3px; cursor: pointer; margin: 3px; font-size: 13px; transition: background-color 0.2s; }
        .btn:hover { background: #0056b3; }
        .extracted-text { background: white; padding: 8px; border: 1px solid #ddd; border-radius: 3px; font-family: 'Courier New', monospace; white-space: pre-wrap; flex-grow: 1; overflow-y: auto; min-height: 200px; font-size: 13px; line-height: 1.4; }
        input[type="file"] { display: none; }
        .copy-btn { background: #28a745; }
        .copy-btn:hover { background: #218838; }
        .result-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
        .processing { color: #666; font-style: italic; }
        .engine-badge { background: #007bff; color: white; padding: 2px 6px; border-radius: 3px; font-size: 0.8em; font-weight: bold; }
        .status-badge { padding: 2px 6px; border-radius: 3px; font-size: 0.8em; font-weight: bold; }
        .status-ok { background: #28a745; color: white; }
        .status-error { background: #dc3545; color: white; }
        .performance { background: #e3f2fd; padding: 4px 8px; border-radius: 3px; font-size: 0.8em; color: #1976d2; margin-left: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>OCR Simple</h1>
            <p class="subtitle">Powered by <span class="engine-badge">Tesseract OCR</span> - Reliable Text Recognition 
                <span class="status-badge {{.StatusClass}}" id="statusBadge">{{.Status}}</span>
                <span class="performance">⚡ Optimized</span>
            </p>
        </div>
        
        {{.SetupWarning}}
        
        <div class="side-by-side">
            <div class="left-panel">
                <h3>Input Gambar:</h3>
                <div class="upload-area" id="uploadArea">
                    <div>Paste gambar (Ctrl+V), drag & drop, atau klik Browse</div>
                    <input type="file" id="fileInput" accept="image/*">
                    <button type="button" class="btn" onclick="document.getElementById('fileInput').click()">Browse</button>
                </div>
            </div>
            
            <div class="right-panel">
                <div class="result-header">
                    <h3>Hasil OCR:</h3>
                    <div>
                        <span id="processingTime" style="font-size: 0.8em; color: #666; margin-right: 10px;"></span>
                        <button class="btn copy-btn" id="copyBtn" onclick="copyText()" style="display: none;">Copy Text</button>
                    </div>
                </div>
                <div class="extracted-text" id="extractedText">{{.InitialMessage}}</div>
            </div>
        </div>
    </div>

    <script>
        let currentFile = null;
        let startTime = null;
        const uploadArea = document.getElementById('uploadArea');
        const fileInput = document.getElementById('fileInput');
        const extractedText = document.getElementById('extractedText');
        const copyBtn = document.getElementById('copyBtn');
        const processingTime = document.getElementById('processingTime');

        // Optimized paste handling
        document.addEventListener('paste', (e) => {
            const items = e.clipboardData.items;
            for (let item of items) {
                if (item.type.startsWith('image/')) {
                    const file = item.getAsFile();
                    handleFile(file);
                    break;
                }
            }
        });

        // Optimized file input change
        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                handleFile(e.target.files[0]);
            }
        });

        // Optimized drag and drop with debouncing
        let dragTimeout = null;
        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('dragover');
            clearTimeout(dragTimeout);
        });

        uploadArea.addEventListener('dragleave', () => {
            dragTimeout = setTimeout(() => {
                uploadArea.classList.remove('dragover');
            }, 100);
        });

        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('dragover');
            clearTimeout(dragTimeout);
            const files = e.dataTransfer.files;
            if (files.length > 0 && files[0].type.startsWith('image/')) {
                handleFile(files[0]);
            }
        });

        function handleFile(file) {
            // Validate file size (max 5MB)
            if (file.size > 5 * 1024 * 1024) {
                extractedText.textContent = 'Error: File too large. Maximum size is 5MB.';
                return;
            }

            currentFile = file;
            
            // Optimized image preview
            const reader = new FileReader();
            reader.onload = function(e) {
                // Use requestAnimationFrame for smooth UI updates
                requestAnimationFrame(() => {
                    uploadArea.innerHTML = '<img src="' + e.target.result + '" class="image-preview" alt="Preview">';
                    extractText();
                });
            };
            reader.readAsDataURL(file);
        }

        function extractText() {
            if (!currentFile) return;
            
            startTime = performance.now();
            
            // Optimized DOM updates
            const updates = () => {
                extractedText.textContent = '⚡ Processing with Tesseract OCR...';
                extractedText.className = 'extracted-text processing';
                copyBtn.style.display = 'none';
                processingTime.textContent = '';
            };
            requestAnimationFrame(updates);
            
            const formData = new FormData();
            formData.append('image', currentFile);
            
            // Optimized fetch with timeout
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 30000); // 30s timeout
            
            fetch('/upload', {
                method: 'POST',
                body: formData,
                signal: controller.signal
            })
            .then(r => {
                clearTimeout(timeoutId);
                return r.json();
            })
            .then(d => {
                const endTime = performance.now();
                const duration = ((endTime - startTime) / 1000).toFixed(2);
                
                // Batch DOM updates for better performance
                requestAnimationFrame(() => {
                    extractedText.className = 'extracted-text';
                    const text = d.text || 'No text detected by Tesseract OCR.';
                    extractedText.textContent = d.error ? 'Error: ' + d.error : text;
                    processingTime.textContent = '⏱️ ' + duration + 's';
                    
                    if (!d.error && d.text) {
                        copyBtn.style.display = 'inline-block';
                        // Pre-copy to clipboard for faster access
                        navigator.clipboard.writeText(d.text).catch(() => {});
                    }
                });
            })
            .catch(e => {
                clearTimeout(timeoutId);
                requestAnimationFrame(() => {
                    extractedText.className = 'extracted-text';
                    extractedText.textContent = 'Error: ' + (e.name === 'AbortError' ? 'Request timeout' : e.message);
                    processingTime.textContent = '❌ Failed';
                });
            });
        }

        function copyText() {
            navigator.clipboard.writeText(extractedText.textContent).then(() => {
                const originalText = copyBtn.textContent;
                copyBtn.textContent = 'Copied!';
                copyBtn.style.background = '#28a745';
                setTimeout(() => {
                    copyBtn.textContent = originalText;
                    copyBtn.style.background = '#28a745';
                }, 1000);
            });
        }
    </script>
</body>
</html>`

	templateCache["home"], err = template.New("home").Parse(homeTmpl)
	if err != nil {
		log.Printf("Error precompiling home template: %v", err)
	}
}

func setupHandler(w http.ResponseWriter, r *http.Request) {
	// Use cached template
	templateMutex.RLock()
	tmpl, exists := templateCache["setup"]
	templateMutex.RUnlock()

	if !exists {
		http.Error(w, "Template not found", http.StatusInternalServerError)
		return
	}

	// Set caching headers for static content
	w.Header().Set("Cache-Control", "public, max-age=300") // 5 minutes
	w.Header().Set("Content-Type", "text/html; charset=utf-8")

	tmpl.Execute(w, nil)
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	// Use cached template
	templateMutex.RLock()
	tmpl, exists := templateCache["home"]
	templateMutex.RUnlock()

	if !exists {
		http.Error(w, "Template not found", http.StatusInternalServerError)
		return
	}

	// Set optimized headers
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")

	data := struct {
		Status         string
		StatusClass    string
		SetupWarning   string
		InitialMessage string
	}{
		Status:         "Ready",
		StatusClass:    "status-ok",
		SetupWarning:   "",
		InitialMessage: "Belum ada gambar yang diproses...",
	}

	if !tesseractFound || ocrClient == nil {
		data.Status = "Not Configured"
		data.StatusClass = "status-error"
		data.SetupWarning = `<div class="setup-warning">⚠️ Tesseract OCR not installed. <a href="/setup">Click here for installation instructions</a></div>`
		data.InitialMessage = "Tesseract OCR not installed. Please visit the setup page to install Tesseract OCR."
	}

	tmpl.Execute(w, data)
}

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	// Set optimized headers
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache")

	// Check if OCR client is initialized
	if !tesseractFound || ocrClient == nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"error": "Tesseract OCR not configured. Please visit /setup for installation instructions."}`))
		return
	}

	// Optimized form parsing
	err := r.ParseMultipartForm(5 << 20) // 5 MB max
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error": "File too large or invalid form data"}`))
		return
	}

	// Get file from form
	file, header, err := r.FormFile("image")
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error": "No file uploaded or invalid file"}`))
		return
	}
	defer file.Close()

	// Fast file type validation
	if !isValidImageType(header.Filename) {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error": "Please upload a valid image file (PNG, JPG, JPEG, GIF, BMP, TIFF)"}`))
		return
	}

	// Efficient file reading with buffer reuse
	buf := bufferPool.Get().([]byte)
	defer bufferPool.Put(buf[:0])

	fileBytes, err := io.ReadAll(file)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"error": "Failed to read uploaded file"}`))
		return
	}

	// Use worker pool for concurrent OCR processing
	responseCh := make(chan OCRResponse, 1)

	select {
	case ocrWorkerPool <- OCRRequest{
		ImageBytes: fileBytes,
		Filename:   header.Filename,
		ResponseCh: responseCh,
	}:
		// Request sent to worker pool
	case <-time.After(5 * time.Second):
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"error": "OCR service busy, please try again"}`))
		return
	}

	// Wait for result
	select {
	case result := <-responseCh:
		if result.Err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf(`{"error": "OCR failed: %v"}`, result.Err)))
			return
		}

		// Pre-allocated response structure for better performance
		response := struct {
			Text     string `json:"text"`
			Filename string `json:"filename"`
			Engine   string `json:"engine"`
		}{
			Text:     result.Text,
			Filename: header.Filename,
			Engine:   "Tesseract OCR",
		}

		// Use optimized JSON encoding
		encoder := json.NewEncoder(w)
		encoder.Encode(response)

	case <-time.After(35 * time.Second):
		w.WriteHeader(http.StatusRequestTimeout)
		w.Write([]byte(`{"error": "OCR processing timeout"}`))
	}
}

func isValidImageType(filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	// Pre-defined slice for better performance
	validExts := [6]string{".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff"}
	for _, validExt := range validExts {
		if ext == validExt {
			return true
		}
	}
	return false
}

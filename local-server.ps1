$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, 8000)
$listener.Start()

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $reader = [System.IO.StreamReader]::new($stream)
        $requestLine = $reader.ReadLine()
        while (($header = $reader.ReadLine()) -ne '') { }

        $urlPath = $requestLine.Split(' ')[1].Split('?')[0]
        $relativePath = [Uri]::UnescapeDataString($urlPath).TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = 'index.html' }

        $filePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($rootPath, $relativePath))
        if ($filePath.StartsWith($rootPath) -and [System.IO.File]::Exists($filePath)) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $mimeTypes = @{ '.html' = 'text/html; charset=utf-8'; '.png' = 'image/png'; '.css' = 'text/css'; '.js' = 'application/javascript' }
            $contentType = $mimeTypes[[System.IO.Path]::GetExtension($filePath).ToLowerInvariant()]
            if (-not $contentType) { $contentType = 'application/octet-stream' }
            $responseHeader = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        } else {
            $bytes = [Text.Encoding]::UTF8.GetBytes('No encontrado')
            $responseHeader = "HTTP/1.1 404 Not Found`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        }

        $headerBytes = [Text.Encoding]::ASCII.GetBytes($responseHeader)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($bytes, 0, $bytes.Length)
    } catch {
        # Una solicitud incompleta no debe detener la vista local.
    } finally {
        $client.Close()
    }
}

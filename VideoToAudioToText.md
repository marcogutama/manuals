# Pasar video a audio
ffmpeg -i "Uso de KIRO #1.webm" -q:a 0 -map a "audio1.mp3"

# Pasar audio a texto

# Crear y activar el entorno virtual (una sola vez)
python3 -m venv whisper-env
source whisper-env/bin/activate

# Instalar whisper dentro del entorno (una sola vez)
pip install openai-whisper

# Transcribir cada audio (esto sí lo repites por archivo)
whisper audio1.mp3 --language Spanish --model medium --output_format txt
whisper audio2.mp3 --language Spanish --model medium --output_format txt
whisper audio3.mp3 --language Spanish --model medium --output_format txt
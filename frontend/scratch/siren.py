import wave, struct, math
import os

sample_rate = 44100
num_samples = 44100 * 3 # 3 seconds

path = r'C:\Users\Script-Kid\Desktop\KhuNyiKalSal\frontend\android\app\src\main\res\raw\emergency_alarm.wav'
wavef = wave.open(path, 'w')
wavef.setnchannels(1)
wavef.setsampwidth(2)
wavef.setframerate(sample_rate)

# Siren sound frequency modulation
for i in range(num_samples):
    t = float(i) / sample_rate
    # Modulate frequency between 600Hz and 1000Hz (2 times a second)
    freq = 800 + 200 * math.sin(2 * math.pi * 3 * t)
    # Generate the actual sine wave at the modulated frequency
    value = int(32767.0 * math.sin(2 * math.pi * freq * t))
    wavef.writeframesraw(struct.pack('<h', value))

wavef.close()
print(f"Generated siren at {path}")

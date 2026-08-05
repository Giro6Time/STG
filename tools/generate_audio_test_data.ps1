param(
	[string]$OutputDirectory = (Join-Path $PSScriptRoot '..\Art\Audio\Test')
)

$sampleRate = 44100
$encoding = [System.Text.Encoding]::ASCII


function New-ToneSamples {
	param(
		[double[]]$Frequencies,
		[double]$DurationSeconds,
		[double]$Gain = 0.25,
		[double]$PulseIntervalSeconds = 0.0
	)

	$sampleCount = [int]($sampleRate * $DurationSeconds)
	$samples = [int16[]]::new($sampleCount)
	for ($index = 0; $index -lt $sampleCount; $index++) {
		$time = $index / $sampleRate
		$envelope = 1.0
		if ($DurationSeconds -le 0.5) {
			$envelope = [Math]::Exp(-7.0 * $time / $DurationSeconds)
		}
		if ($PulseIntervalSeconds -gt 0.0) {
			$pulseTime = $time % $PulseIntervalSeconds
			$envelope = [Math]::Exp(-14.0 * $pulseTime)
		}

		$value = 0.0
		foreach ($frequency in $Frequencies) {
			$value += [Math]::Sin(2.0 * [Math]::PI * $frequency * $time)
		}
		$value = $value / [Math]::Max(1, $Frequencies.Count)
		$scaledValue = $value * $envelope * $Gain * 32767.0
		$clampedValue = [Math]::Max(-32767.0, [Math]::Min(32767.0, $scaledValue))
		$samples[$index] = [int16]$clampedValue
	}
	return $samples
}


function Write-PcmWave {
	param(
		[string]$Path,
		[int16[]]$Samples
	)

	$dataSize = $Samples.Length * 2
	$stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
	$writer = [System.IO.BinaryWriter]::new($stream)
	try {
		$writer.Write($encoding.GetBytes('RIFF'))
		$writer.Write(36 + $dataSize)
		$writer.Write($encoding.GetBytes('WAVE'))
		$writer.Write($encoding.GetBytes('fmt '))
		$writer.Write(16)
		$writer.Write([int16]1)
		$writer.Write([int16]1)
		$writer.Write($sampleRate)
		$writer.Write($sampleRate * 2)
		$writer.Write([int16]2)
		$writer.Write([int16]16)
		$writer.Write($encoding.GetBytes('data'))
		$writer.Write($dataSize)
		foreach ($sample in $Samples) {
			$writer.Write($sample)
		}
	}
	finally {
		$writer.Dispose()
		$stream.Dispose()
	}
}


New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$definitions = @(
	@{ Name = 'sfx_ping.wav'; Frequencies = @(880.0, 1320.0); Duration = 0.18; Gain = 0.32; Pulse = 0.0 },
	@{ Name = 'sfx_hit.wav'; Frequencies = @(180.0, 240.0); Duration = 0.24; Gain = 0.38; Pulse = 0.0 },
	@{ Name = 'sfx_follow_loop.wav'; Frequencies = @(110.0, 165.0); Duration = 1.0; Gain = 0.18; Pulse = 0.0 },
	@{ Name = 'sfx_interrupt.wav'; Frequencies = @(520.0); Duration = 0.45; Gain = 0.30; Pulse = 0.0 },
	@{ Name = 'sfx_once_per_frame.wav'; Frequencies = @(1500.0); Duration = 0.08; Gain = 0.22; Pulse = 0.0 },
	@{ Name = 'bgm_stage_primary.wav'; Frequencies = @(220.0, 277.18, 329.63); Duration = 4.0; Gain = 0.12; Pulse = 0.0 },
	@{ Name = 'bgm_stage_layer.wav'; Frequencies = @(90.0); Duration = 4.0; Gain = 0.26; Pulse = 0.5 },
	@{ Name = 'bgm_boss_intro.wav'; Frequencies = @(146.83, 220.0); Duration = 2.0; Gain = 0.15; Pulse = 0.0 },
	@{ Name = 'bgm_boss_primary.wav'; Frequencies = @(146.83, 174.61, 220.0); Duration = 4.0; Gain = 0.15; Pulse = 0.0 },
	@{ Name = 'bgm_boss_layer.wav'; Frequencies = @(75.0, 110.0); Duration = 4.0; Gain = 0.24; Pulse = 0.25 }
)

foreach ($definition in $definitions) {
	$samples = New-ToneSamples -Frequencies $definition.Frequencies -DurationSeconds $definition.Duration -Gain $definition.Gain -PulseIntervalSeconds $definition.Pulse
	Write-PcmWave -Path (Join-Path $OutputDirectory $definition.Name) -Samples $samples
}

Write-Host "Generated $($definitions.Count) audio test files in $OutputDirectory"

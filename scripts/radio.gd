extends AudioStreamPlayer
# Original synthesized station loops; no external media or network required.
const RATE := 22050
const TEMPOS := [96.0, 124.0, 150.0, 110.0]
var station := -1
var loops: Dictionary = {}

func _exit_tree() -> void:
	stop()
	stream = null
	loops.clear()

func tune(index: int) -> void:
	index = posmod(index,TEMPOS.size())
	if station == index and playing:
		return
	station = index
	if not loops.has(index):
		loops[index] = _compose(index)
	stream = loops[index]
	play()

func _compose(index: int) -> AudioStreamWAV:
	var beat: float = 60.0/TEMPOS[index]
	var count := int(beat*16.0*RATE)
	var pcm := PackedByteArray()
	pcm.resize(count*2)
	var notes := [0,3,7,5]
	for sample in count:
		var t := float(sample)/RATE
		var step := int(t/beat)
		var phase := fmod(t,beat)
		var root_hz := 55.0*pow(2.0,float(notes[(step/4)%4])/12.0)
		var bass := sin(TAU*root_hz*t)*exp(-phase*4.0)*0.2
		var kick := sin(TAU*(45.0*phase+8.0*(1.0-exp(-phase*30.0))))*exp(-phase*24.0)*0.32
		var hat_phase := fmod(t,beat/2.0)
		var noise := sin(sample*12.9898+index*78.233)*43758.5453
		noise = (noise-floor(noise))*2.0-1.0
		var drums := noise*exp(-hat_phase*100.0)*0.08
		if step%2 == 1:
			drums += noise*exp(-phase*25.0)*0.12
		var melody_hz := root_hz*pow(2.0,float([12,19,15,22][step%4])/12.0)
		var tone := sin(TAU*melody_hz*t)
		if index == 2:
			tone = tanh(tone*3.0)
		elif index == 0:
			tone += sin(TAU*melody_hz*2.0*t)*0.25
		var melody := tone*exp(-phase*(8.0 if index != 3 else 3.0))*0.12
		var fade := minf(1.0,minf(t*100.0,(float(count-sample)/RATE)*100.0))
		var value := int(clampf((bass+kick+drums+melody)*fade,-1.0,1.0)*32767.0)
		pcm.encode_s16(sample*2,value)
	var loop := AudioStreamWAV.new()
	loop.format = AudioStreamWAV.FORMAT_16_BITS
	loop.mix_rate = RATE
	loop.data = pcm
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = count
	return loop

require 'wavefile'

class PicoTune
  SAMPLE_RATE = 11468
  TONE_CONSTANT = 1.059463
  FREQUENCIES = {
    C: 32.70,
    'C#': 34.65,
    'Db': 34.65,
    D: 36.71,
    'D#': 38.89,
    'Eb': 38.89,
    E: 41.20,
    F: 43.65,
    'F#': 46.25,
    'Gb': 46.25,
    G: 49.0,
    'G#': 51.91,
    'Ab': 51.91,
    A: 55.00,
    'A#': 58.27,
    'Bb': 58.27,
    B: 61.74
  }

  def initialize filename
    @filename = filename
    @assembler = Assembler.new filename
    @tune = @assembler.assemble
  end

  def wav
    @tune.wav
  end
end

class PicoTune::Sample
  attr_reader :left, :right

  def to_a
    [@left, @right]
  end

  def initialize left = 0.0, right = 0.0
    @left, @right = left.to_f, right.to_f
  end

  def add sample
    @left += sample.left
    @right += sample.right

    # "foldback" instead of hard clipping, sounds cool
    if @left > 1.0
      @left = 1.0 - (@left - 1.0) # ex: 1.0 - (1.2 - 1.0) => 1.0 - 0.2 => 0.8
    elsif @left < -1.0
      @left = -1.0 - (@left + 1.0) # ex: -1.0 - (-1.2 + 1.0) => -1.0 - -0.2 => -0.8
    end

    if @right > 1.0
      @right = 1.0 - (@right - 1.0)
    elsif @right < -1.0
      @right = -1.0 - (@right + 1.0)
    end

    self # return self to chain ops EX: sample.add(sample).add(sample) etc
  end

  def modify_left operator, modifier
    @left = @left.send operator, modifier
  end

  def modify_right operator, modifier
    @right = @right.send operator, modifier
  end
end

class PicoTune::WaveSample
  def initialize tone, samples_per_wave, multiplier = nil
    @tone = tone
    @samples_per_wave = samples_per_wave
    @multiplier = multiplier
  end

  def sample index
    value = case @tone
      when 'square'
        square index
      when 'sine'
        sine index
      when 'triangle'
        triangle index
      when 'noise'
        noise index
      when 'saw'
        saw index
      else
        sine index
      end

    PicoTune::Sample.new value, value
  end

  def sine index
    Math.sin(index / (@samples_per_wave / (Math::PI * 2))) * (@multiplier || 0.5)
  end

  def saw index
    interval = @samples_per_wave / 2
    half_interval = interval / 2
    percent = ((index + half_interval) % interval) / interval.to_f
    ((0.6 * percent) - 0.3) * (@multiplier || 0.5)
  end

  def square index
    (index <= @samples_per_wave / 2 ? 1.0 : -1.0) * (@multiplier || 0.25)
  end

  def noise index
    value = sine index
    rand = Random.rand - 0.5
    value * rand * (@multiplier || 0.5)
  end

  def triangle index
    half = @samples_per_wave / 2
    quarter = @samples_per_wave / 4
    ramp = 1.0 / quarter
    m = @multiplier || 0.5

    if index <= half
      if index <= quarter
        index * ramp * m
      else
        (half - index) * ramp * m
      end
    else
      if index <= half + quarter
        -((index - half) * ramp) * m
      else
        -((@samples_per_wave - index) * ramp) * m
      end
    end
  end
end

class PicoTune::Tune
  attr_reader :name, :sequence, :phrases

  def initialize name, sequence, phrases
    @name = name
    @sequence = sequence
    @phrases = phrases
  end

  def buffer
    @buffer ||= begin
      tune_buffer_length = @sequence.reduce(0) do |acc, phrase_name|
        acc + @phrases.find { |p| p.name == phrase_name }.buffer_size
      end

      offset = 0
      samples = Array.new(tune_buffer_length) { PicoTune::Sample.new }

      @sequence.each do |phrase_name|
        phrase = @phrases.find { |p| p.name == phrase_name }

        phrase.buffer.each_with_index do |phrase_sample, index|
          tune_sample = samples[offset + index] || PicoTune::Sample.new
          tune_sample.add phrase_sample
          samples[offset + index] = tune_sample
        end

        offset += phrase.buffer_size
      end

      samples
    end
  end

  def wav
    @wav ||= begin
      wav_format = WaveFile::Format.new :stereo, :float, PicoTune::SAMPLE_RATE
      wav_buffer = WaveFile::Buffer.new buffer.map(&:to_a), wav_format
      name = "#{@name}.wav"

      WaveFile::Writer.new(name, WaveFile::Format.new(:stereo, :pcm_8, PicoTune::SAMPLE_RATE)) do |writer|
        writer.write(wav_buffer)
      end

      name
    end
  end
end

class PicoTune::Phrase
  attr_reader :name, :tempo, :beats, :subbeats, :melodies

  def initialize name, tempo, beats, subbeats, melodies
    @name = name
    @tempo = tempo.to_i
    @beats = beats.to_i
    @subbeats = subbeats.to_i
    @melodies = melodies
  end

  def seconds_per_beat
    60.0 / @tempo
  end

  def seconds_per_measure
    seconds_per_beat * @beats
  end

  def buffer_size
    (seconds_per_measure * PicoTune::SAMPLE_RATE).to_i
  end

  def buffer
    @buffer ||= begin
      samples = Array.new(buffer_size) { PicoTune::Sample.new }

      @melodies.each do |melody|
        temp = Array.new(buffer_size) { PicoTune::Sample.new } if melody.instrument.reverb?
        sub_buffer_size = (buffer_size.to_f / (@beats * @subbeats)).ceil
        last_step_number = -1
        carry_over = 0

        if melody.pattern.steps.count != @beats * @subbeats
          raise "Mismatch between Pattern \"#{melody.pattern.name}\", which has #{melody.pattern.steps.count} steps, and Phrase \"#{@name}\", which has #{@beats} beats and #{subbeats} subbeats (meaning any pattern it uses should have #{@beats * @subbeats} steps). Please check your pattern and phrase definitions to find the discrepancy!"
        end

        melody.pattern.steps.each_with_index do |note, step_number|
          unless note == '.'
            buffer_pointer = step_number * sub_buffer_size
            local_index = 0
            wave_index = 0
            length_offset = (1 - melody.instrument.length_value) * sub_buffer_size

            if step_number == last_step_number + 1
              local_index = carry_over
            end

            carry_over = 0

            while local_index + length_offset < sub_buffer_size || !wave_index.zero?
              current_sample = (temp ? temp : samples)[buffer_pointer + local_index] || PicoTune::Sample.new

              new_sample = melody.instrument.wave wave_index, note

              current_sample.add new_sample

              (temp ? temp : samples)[buffer_pointer + local_index] = current_sample

              wave_index += 1
              local_index += 1
              last_step_number = step_number
              carry_over += 1 if local_index + length_offset >= sub_buffer_size
              wave_index = 0 if wave_index >= melody.instrument.samples_per_wave(note)
            end

            if melody.instrument.reverb?
              i = 0
              while i < temp.size
                if i + melody.instrument.reverb_offset < temp.size
                  verb_sample = temp[i + melody.instrument.reverb_offset]
                  verb_sample.modify_left :+, temp[i].left * melody.instrument.decay
                  verb_sample.modify_right :+, temp[i].right * melody.instrument.decay

                  temp[i + melody.instrument.reverb_offset] = verb_sample
                end

                samples[i] = samples[i].add temp[i]
                
                i += 1
              end
            end
          end
        end
      end

      samples
    end
  end
end

class PicoTune::Instrument
  attr_reader :name, :tone, :length, :volume, :pan, :reverb

  def initialize name, tone = 0, length = 'full', volume = 'full', pan = 'center', reverb = 'none'
    @name = name
    @tone = tone
    @length = length
    @volume = volume
    @pan = pan
    @reverb = reverb
  end

  def length_value
    case @length
    when 'none'
      0.0
    when 'quarter'
      0.25
    when 'half'
      0.5
    when 'threequarters'
      0.75
    when 'full'
      1.0
    end
  end

  def volume_value
    case @volume
    when 'none'
      0.0
    when 'quarter'
      0.25
    when 'half'
      0.5
    when 'threequarters'
      0.75
    when 'full'
      1.0
    end
  end

  def pan_value
    case @pan
    when 'left'
      0
    when 'centerleft'
      1
    when 'center'
      2
    when 'centerright'
      3
    when 'right'
      4
    end
  end

  def delay
    @reverb == 'none' ? 0.0 : 0.1
  end

  def decay
    case @reverb
    when 'none'
      0.0
    when 'some'
      0.25
    when 'more'
      0.5
    when 'lots'
      0.75
    else
      0.0
    end
  end

  def reverb_offset
    (PicoTune::SAMPLE_RATE * delay).floor
  end

  def reverb?
    %w(some more lots).include? @reverb
  end

  def wave wave_index, note 
    frequency = frequency_for_note note
    samples_per_wave = (PicoTune::SAMPLE_RATE / frequency).ceil
    sample = PicoTune::WaveSample.new(@tone, samples_per_wave).sample wave_index
    sample.modify_left :*, volume_value * (1 - pan_value / 4.0)
    sample.modify_right :*, volume_value * (pan_value / 4.0)
    sample
  end

  def samples_per_wave note
    frequency = frequency_for_note note
    (PicoTune::SAMPLE_RATE / frequency).ceil end

  def frequency_for_note note
    parts = note.split ''
    octave = parts.pop.to_i
    name = parts.join.to_sym
    freq = PicoTune::FREQUENCIES[name]

    raise "Bad note: #{name} from #{note}. Valid note names are <C, C# or Db, D, D# or Eb, E, F, F# or Gb, G, G# or Ab, A, A# or Bb, B>" unless freq
    raise "Bad octave: #{octave} from #{note}. Valid octave number is 1..8" unless (1..8).include?(octave)

    octave_shift = PicoTune::TONE_CONSTANT ** 12
    (octave - 1).times { freq = freq * octave_shift }

    freq
  end
end

class PicoTune::Melody
  attr_reader :instrument, :pattern

  def initialize instrument, pattern
    raise 'nil instrument' if instrument.nil?
    raise 'nil pattern' if pattern.nil?

    @instrument = instrument
    @pattern = pattern
  end
end

class PicoTune::Pattern
  attr_reader :name, :steps

  def initialize name, steps
    @name = name
    @steps = steps
  end
end

class PicoTune::Assembler
  attr_reader :phrases, :instruments, :patterns
  
  def initialize file
    @file = file
    @parser = PicoTune::Parser.new file
  end

  def assemble
    patterns = []
    phrases = []

    list = @parser.parse

    instruments = list.select { |item| item['type'] == 'instrument' }.map do |item|
      PicoTune::Instrument.new(
        item['name'],
        item['tone'],
        item['length'],
        item['volume'],
        item['pan'],
        item['reverb']
      )
    end

    patterns = list.select { |item| item['type'] == 'pattern' }.map do |item|
      PicoTune::Pattern.new item['name'], item['list']
    end

    phrases = list.select { |item| item['type'] == 'phrase' }.map do |item|
      melodies = item['melodies'].map do |m|
        instrument = instruments.find { |i| i.name == m[0] }

        raise "Instrument named \"#{m[0]}\" doesn't exist!" unless instrument

        pattern = patterns.find { |p| p.name == m[1] }

        raise "Pattern named \"#{m[1]}\" doesn't exist!" unless pattern

        PicoTune::Melody.new instrument, pattern
      end

      PicoTune::Phrase.new(
        item['name'],
        item['tempo'],
        item['beats'],
        item['subbeats'],
        melodies
      )
    end

    sequence = list.find { |item| item['type'] == 'sequence' }

    raise "Please define a sequence in your txt file with \"sequence s1 s2 s3...\" where s1/s2/s3/etc are names of phrases" unless sequence

    sequence['list'].each do |phrase_name|
      raise "undefined phrase \"#{phrase_name}\" in sequence" unless phrases.find { |p| p.name == phrase_name }
    end

    tune = list.find { |item| item['type'] == 'tune' }

    raise "Please define your tune's name in your txt file  with \"tune <tune name>\"" unless tune && tune['name']

    PicoTune::Tune.new tune['name'], sequence['list'], phrases
  end
end

class PicoTune::Parser
  def initialize file
    @lines = File.open(file).readlines.map(&:strip)
    @keywords = ['tune ', 'sequence', 'instrument ', 'phrase ', 'pattern ']
  end

  def parse
    i = 0
    bag = []
    collecting_melodies = false

    while i < @lines.length
      line = @lines[i]

      if line.start_with? *@keywords
        collecting_melodies = false
        parts = line.split ' '
        item = {}

        item['type'] = parts[0]

        if parts[0] == 'sequence'
          item['list'] = parts[1..-1]
        elsif parts[0] == 'pattern'
          item['name'] = parts[1]
          item['list'] = pattern_steps parts[2..-1].join
        else
          item['name'] = parts[1..-1].join
        end

        bag << item
      elsif line.length > 0
        parts = line.split ' '

        if bag.last['type'] == 'phrase' && parts[0] == 'melodies'
          collecting_melodies = true
          bag.last['melodies'] = []
        elsif collecting_melodies
          bag.last['melodies'].push parts
        else
          bag.last[parts[0]] = parts[1..-1].join
        end
      end
      
      i += 1
    end

    bag
  end

  def pattern_steps pattern
    p = pattern.split(/([a-zA-Z][#b]?\d)/, -1)
               .map { |b| b.split(/(\.|-)/, -1) }
               .flatten
               .delete_if { |b| b.length.zero? }

    i = 0
    while i < p.length
      if p[i] == '-'
        p[i] = p[i - 1]
      end

      i += 1
    end

    p
  end
end

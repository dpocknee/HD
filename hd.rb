#  ========== 
#  = HD     = 
#  ========== 
# A module for measuring harmonic distance
# test.
require 'rational'
module HD
  require 'set'
  require 'rational'
  PRIMES = [2,3,5,7,11,13,17,19,23]
  
  # Holds the configuration parameters for the various HD measurement functions
  # Settings that are possible as of now: a custom list of prime number weights, 
  # and a custom filename from which to read in a list of tuneable intervals.
  class HDConfig
    attr_accessor :prime_weights, :tuneable, :options
    def initialize(prime_weights = PRIMES.dup, options = {:pc_only => false, :tuneable => "tuneable.txt"})
      if prime_weights.size != PRIMES.size
        PRIMES.size.times do |i|
          if prime_weights[i] == nil
            prime_weights[i] = 0.0
          end
        end
        @prime_weights = prime_weights
      else
        @prime_weights = prime_weights
      end
      @options = options
      
      pattern = /(\d+)\/(\d+)/
      @tuneable = []
      # Reads in the entire list of tuneable intervals from a file
      File.open(options[:tuneable], "r") do |intervals|
        intervals.readlines.each do |line|
          if (pattern =~ line) != nil
            full = Regexp.last_match
            @tuneable << HD::Ratio.new(full[1].to_i, full[2].to_i)
          end
        end
      end
    end
    
    def prime_weights=(new_weights)
      if new_weights.size != PRIMES.size
        PRIMES.size.times do |i|
          if new_weights[i] == nil
            new_weights[i] = 0.0
          end
        end
        @prime_weights = new_weights
      else
        @prime_weights = new_weights
      end
    end
    
  end # HDConfig (class)
  
  # Ratio class, which defines a point in harmonic space.
  # TODO: Figure out how to make this a subclass to Rational
  class Ratio
    include Enumerable
    require 'rational'
    attr_accessor :num, :den
    
    # Default value is 1/1. This make it easier to provide an origin of 1/1 for any distance function.
    def initialize(num = 1, den = 1)
      # The use of rational makes sure that the Ratio is always in reduced form
      r = Rational(num, den)
      @num = r.numerator
      @den = r.denominator
    end
    
    # Predicate: returns whether or not the Ratio satisfies all conditions
    def satisfy?
      ratio = [@num, @den]
      ratio.each do |x|
        return false if (yield x) == false
      end
      true
    end
    
    def dec
      return @num.to_f / @den
    end
    
    def pc_space
      while self.dec >= 2.0
        @den *= 2
      end
      while self.dec < 1.0
        @num *= 2
      end
      
      r = Rational(@num, @den)
      @num = r.numerator
      @den = r.denominator
    end
    
    def * r
      if !r.is_a? Ratio
        raise ArgumentError "Supplied class #{r.class} to HD::Ratio.*"
      end
      Ratio.new(r.num * self.num, r.den * self.den)
    end
    
    def ** i
      if !i.is_a? Object
        raise ArgumentError "Supplied class #{i.class} to HD::Ratio.**"
      end
      Ratio.new(@num ** i, @den ** i)
    end
    
    # Necesssary to test for sets and subsets
    def eql? r
      @num == r.num && @den == r.den
    end
    
    # Defines the hash to properly test for equality
    def hash
      [@num, @den].hash
    end
    
    # Each iterator; required for Enumerable
    def each
      yield @num
      yield @den
    end
    
    # The normal map method returns an Array (we want a Ratio back)
    def map
      num = yield @num
      den = yield @den
      Ratio.new(num, den)
    end
    
    # Reduces the ratio and returns the value
    def reduce
      ratio = self.dup
      PRIMES.each {|z| ratio = ratio.map {|y| y /= z} while ratio.satisfy? {|y| y % z == 0}}
      ratio
    end
    
    # For each of the num and den, provides a list of exponents. Primes are only up through the size of PRIMES.
    def factors
      num = @num
      den = @den
      exponents = [num, den]
      exponents.map! do |y|
        PRIMES.map do |x|
          exp_count = 0
          while y % x == 0
            exp_count += 1
            y /= x
          end
          exp_count
        end
      end
      exponents
    end
    
    # Returns the harmonic distance from another point (or from the origin if no point is specified)
    # Defaults are distance from origin and default HDConfig object
    # an alternate origin may be specified, which would allow for distances from other points
    def distance(origin = HD::Ratio.new, config = HD::HDConfig.new)
      weights = config.prime_weights
      me = self.dup
      me.num *= origin.den
      me.den *= origin.num
      me = me.reduce
      factors = me.factors
      warn "Weights and factors are not the same size!" if factors[0].size != weights.size
      # Uses the "city blocks" metric
      city_blocks = 1
      for factor in factors
        weights.each_with_index do |w,i|
          city_blocks *= w ** factor[i]
        end
      end
      if city_blocks == 0
        return Math::log2(city_blocks) * -1
      end
      return Math::log2(city_blocks)
    end
    
    # Allows for an array of Ratio objects to be sorted according to size (scale order)
    def <=> other
      return self.num.to_f / self.den <=> other.num.to_f / other.den
    end
    
    def < other
      return self.num.to_f / self.den < other.num.to_f / other.den
    end
    
    def > other
      return self.num.to_f / self.den > other.num.to_f / other.den
    end
    
    def to_s
      return "#{@num}/#{@den}"
    end
  end # Ratio (Class)
  
  # The chord is essentially just a sorted set that translates some of the basic
  # functions so that they'll work with the Ratio objects. It also will calculate
  # the total distance between all possible points (combinatorial summation) and 
  # can return a set of all possible pairs.
  class Chord < SortedSet

    # Iterate through and create a set of pairs, not counting pairs of the same chord
    def pairs
      pairs = Set.new
      self.each do |x|
        self.each do |y|
          pairs << [x, y].sort
        end
      end
      pairs.reject! {|x| x[0] == x[1]}
      pairs
    end
    
    # sum of the combinatorial distance of all members of the chord.
    # the distance between each possible pair is computed, and that
    # amount is summed to compute the total distance
    def hd_sum(config = HD::HDConfig.new)
      total = 0
      all_pairs = []
      self.pairs.each {|x,y| all_pairs << [x,y]}
      all_pairs.each {|x| total += x[0].distance(x[1], config)}
      total
    end
    
    # See "Crystal Growth in Harmonic Space," by James Tenney
    # as well as the tables and refinements suggested by
    # Marc Sabat & Wolfgang von Schweinitz (plainsound.org)
    #
    # Finds the point which is the least possible harmonic distance
    # from all other points, while not being a member of the chord
    # itself. Should have the smallest possible return of 
    # total_distance when added to the chord.
    #
    # 1. Look through all tuneable intervals for each member
    # 2. Add each one to the chord, and evaluate total_distance
    # 3. Pick the interval with the least total_distance
    def logical_origin(config = HDConfig.new)
      least_harmonic_distance = {:distance => nil, :ratio => nil}
      self.each do |m|
        config.tuneable.each do |i|
          if self.member? m * i
            next
          end
          if (m * i) > Ratio.new(9,2) || (m * i) < Ratio.new(4,9)
            next
          end
          c = self.dup
          c << m * i
          if (least_harmonic_distance[:ratio] == nil)
            least_harmonic_distance[:ratio] = m * i
            least_harmonic_distance[:distance] = c.hd_sum(config)
          elsif (least_harmonic_distance[:distance] > c.hd_sum(config))
            least_harmonic_distance[:ratio] = m * i
            least_harmonic_distance[:distance] = c.hd_sum(config)
          end
        end
      end
      least_harmonic_distance
    end
    
    # Returns an array of all possible candidates connected to the pitches
    # Optional argument pc_only allows for consideration of only pitch-class
    # projection space (where octave equivalency is respected)
    def candidates(config = HD::HDConfig.new)
      candidates = []
      self.each do |e|
        PRIMES.each do |p|
          # Add each connected element
          candidates << e * Ratio.new(p, 1)
          candidates << e * Ratio.new(1, p)
        end
      end
      # Filter everything for pitch-class space
      if config.options[:pc_only]
        candidates.each do |x|
          x = x.pc_space
        end
        candidates = candidates & candidates
      end
      candidates.reject! {|x| self.include? x}
      candidates
    end
    
    def to_s
      str = ""
      self.each {|x| str << x}
    end
  end # Chord (Class)
  
  class WeightedArray < Array
    def initialize(*x)
      if x
        super(x)
      else
        super
      end
      @weights = Array.new(self.size, 1)
    end
  
    def choose
      normalized = []
      # Normalize (divide each weight by the sum of all weights)
      sum = 0.0
      @weights.each {|x| sum += x}
      if sum == 0.0
        raise "WTF SUM IS ZERO"
      end
      normalized = @weights.map {|x| x /= sum }
      normalized.each_with_index {|x,i| x += normalized[i-1] unless i == 0}      
      # Each item should equal itself plus the previous item      
      ranking = Array.new(normalized.size)
      normalized.each_index do |i| 
        if i == 0
          ranking[i] = normalized[i]
        else
          ranking[i] = ranking[i-1] + normalized[i]
        end
      end
      begin
        r = rand
        chosen = 0
        
        while r >= ranking[chosen]
          chosen += 1
        end
      rescue ArgumentError => er
        print "#{er.message}\n#{r}\t#{ranking}"
      end
      
      return self[chosen]
    end
  
    # Sets the new weighting
    def weights=(input_weights)
      if !(input_weights.instance_of? Array)
        return nil
      end
      input_weights.map! {|x| x.to_f}
      @weights = input_weights if input_weights.size == self.size
    end
  
    def weights
      return @weights
    end
  end
  
  # A series of functions for choosing new pitches.
  
  #
  # Select: Provide this thing with a base ratio and a config file (with prime weights 
  # & tuneable intervals) and it'll choose a new pitch based on that prime number weighting.
  # Supremely useful for finding the next interval to use based on harmonic distance, without
  # being entirely deterministic. Essentially creates a distribution of probabilities to shoot for
  # 
  # Ideas: r could be the current origin at all times. So that would create a certain cloud
  # around a particular pitch. When that cloud encroaches on another origin, the cloud
  # may change its origin. That's left for a different controller module.
  #
  
  def self.select(r = Ratio.new, config = HDConfig.new)
    intervals = config.tuneable.map {|x| r * x}
    intervals = WeightedArray.new(*intervals)
    puts "#{intervals}"
    intervals.weights = intervals.map do |x| 
      if x.distance == 0.0
        0.0
      else
        1.0 / x.distance
      end
    end
    puts "#{intervals.weights}"
    intervals.choose
  end
  
end # HD (Module)
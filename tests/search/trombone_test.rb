require 'test/unit'
require_relative '../../hd-mm.rb'
require_relative '../../lib/search/trombone_search.rb'

class TromboneTest < Test::Unit::TestCase
	
	def setup
		start_vector = NArray[[[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]]]
		# start_vector = NArray[[[4, 9], [1, 1]], [[5, 9], [1, 1]], [[7, 9], [1, 1]], [[1, 1], [1, 1]]]
		goal_vector = 0.1
		metric = MM.ucm
		# For metric, we call 
		@opts = {:start_vector => start_vector, :goal_vector => goal_vector, :metric => metric}
	end
	
	def test_trombone_search_should_require_start_vector_narray
		assert_raise ArgumentError do
			@opts[:start_vector] = [[[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]]]
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_require_start_vector_narray_of_shape_2_2_4
		assert_raise ArgumentError do
			@opts[:start_vector] = NArray[[[4, 9], [1, 1]], [[4, 9], [1, 1]], [[4, 9], [1, 1]]]
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_require_goal_vector
		assert_raise ArgumentError do
			@opts[:goal_vector] = nil
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_require_metric
		assert_raise ArgumentError do
			@opts[:metric] = nil
			MM::TromboneSearch.new(@opts)
		end
	end
	def test_trombone_search_should_allow_new_search
		assert_nothing_raised do
			MM::TromboneSearch.new(@opts)
		end
	end
	
	def test_trombone_search_should_prepare_search
		assert_nothing_raised do
			trombone_search = MM::TromboneSearch.new(@opts)
			trombone_search.send(:prepare_search)
		end
	end
	
	def test_trombone_search_should_get_candidate_list
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		assert(trombone_search.send(:get_candidate_list), ":get_candidate_list returned nil or false")
	end
	
	def test_candidate_list_should_respond_to_sort
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		list = trombone_search.send(:get_candidate_list)
		assert(list.respond_to?(:sort))
	end
	
	# This will have to change if the definition of "adjacent point" changes
	def test_candidate_list_should_be_shape_2_2_4_n
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		shape = trombone_search.send(:get_candidate_list).shape
		assert_equal([2, 2, 4], shape[0..2], ":get_candidate_list was shape #{shape}")
		assert_equal(4, shape.size, ":get_candidate_list_returned shape of size #{shape.size}")
	end
	
	def test_trombone_search_parameters_to_ratio_should_require_narray_of_shape_2_2
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_raise ArgumentError do
			trombone_search.send(:parameters_to_ratio, NArray[[4,9]], "parameters_to_ratio accepted NArray of shape [2,1]")
		end
		assert_raise ArgumentError do
			trombone_search.send(:parameters_to_ratio, [[4, 9], [3, 1]], "parameters_to_ratio accepted Array")
		end
	end

	def test_trombone_search_should_convert_parameters_to_ratio
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_equal(HD::Ratio[4, 3], trombone_search.send(:parameters_to_ratio, NArray[[4, 9], [3, 1]]))
	end
	
	# Make sure the parameters_to_ratio function works on a vector of parameters
	def test_trombone_search_should_convert_parameter_vector_to_ratio_vector
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_equal(NArray[[4, 3], [16, 9]], trombone_search.send(:parameter_vector_to_ratio_vector, NArray[[[4, 9], [3, 1]], [[4, 9], [4, 1]]]))
	end
	
	def test_get_cost_should_accept_narray_of_2_2_4
		# Instantiate a DistConfig that holds the proper intra_delta
		config = MM::DistConfig.new(:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => MM::DELTA_FUNCTIONS[:abs_diff])
		# Create a metric that takes this DistConfig
		# Using the closure features of a Proc to lock down the config variables
		@opts[:metric] = ->(a, b) do
			MM.dist_ucm(a, b, config)
		end
		trombone_search = MM::TromboneSearch.new(@opts)
		assert_nothing_raised do
			begin
				trombone_search.send(:get_cost, NArray[[[4, 9], [3, 1]], [[4, 9], [2, 1]], [[4, 9], [4, 1]], [[4, 9], [1, 1]]])
				# If there is a problem, we want to print out the Exception, and re-raise so that the test fails
			rescue Exception => e
				puts e.message
				puts e.backtrace.join("\n")
				raise e
			end
		end
	end
	
	def test_get_candidate_should_return_a_single_candidate
		# Instantiate a DistConfig that holds the proper intra_delta
		config = MM::DistConfig.new(:scale => :none, :intra_delta => MM.get_harmonic_distance_delta(HD::HDConfig.new), :inter_delta => MM::DELTA_FUNCTIONS[:abs_diff])
		@opts[:metric] = ->(a, b) { MM.dist_ucm(a, b, config) }
		trombone_search = MM::TromboneSearch.new(@opts)
		trombone_search.send(:prepare_search)
		# Find the best candidate
		puts "Getting a candidate..."
		candidate = trombone_search.send(:get_candidate, trombone_search.send(:get_candidate_list), 0)
		puts "Candidate got."
		assert(candidate)
		assert_equal([2,2,4], candidate.shape)
	end
end
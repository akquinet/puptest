test_cases = ''

Dir.chdir(File.dirname(__FILE__)) do
  Dir.glob('**/*_test.rb') do |test_case| 
    require "#{File.expand_path(File.dirname(__FILE__))}/#{test_case}"     
    if test_cases != ''
      test_cases += ', '
    end
    test_cases += test_case
  end
end

puts "included test cases: "+test_cases
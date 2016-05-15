processor = %q{
  lambda do |i|
    puts "* Chunk ##{i}"
    result = rand(10)
    sleep rand(10)
    puts "* Finished ##{i}"

    result
  end
}

i = _get_state || 1

loop do
  _emit(i, i, processor) do |position, result|
    _store.save position, result
  end

  i += 1
  _set_state i
end

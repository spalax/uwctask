#
# sort batches
#
def sort(state)
  state ||= { step: :sort, data_position: 0, store_position: 1 }

  batch_size = 5000

  sort_processor = %q{
    lambda do |array|
      array.sort
    end
  }

  while state[:data_position] < _data.length
    data = _data[state[:data_position], state[:data_position] + batch_size - 1]

    _emit(state[:store_position], data, sort_processor) do |position, result|
      _store.save position, result
    end

    state[:data_position] += batch_size
    state[:store_position] += 1

    _set_state state
  end

  _wait_for_all
end

#
# merge sorted batches
#
def merge(state)
  state[:step] = :merge
  state[:last_position] ||= 1

  batch_size = 20

  merge_processor = %q{
    lambda do |arrays|
      arrays.reduce(:+).sort
    end
  }

  iterations_count = calculate_iteration_count(_store.length, batch_size)

  iterations_count.each do |count|

    count.times do
      next_batch = _store.from(state[:last_position], batch_size)

      ids    = next_batch.map { |batch| batch[:id] }
      values = next_batch.map { |batch| JSON.parse(batch[:value]) }

      _emit ids, values, merge_processor do |ids, result|
        _store.save ids[0], result
        _store.delete ids[1..-1]
      end

      state[:last_position] = ids.last + 1
      _set_state state
    end

    _wait_for_all
    state[:last_position] = 1
    _set_state state
  end

  _wait_for_all
  result = _store.from(1, 1).first[:value]
  _finish result
end

#
# calculate iterations count needed to merge all data into one array
#
def calculate_iteration_count(store_length, batch_size)
  iterations_count = []

  loop do
    count = (store_length.to_f / batch_size).ceil
    iterations_count << count
    store_length = count

    break if store_length == 1
  end

  iterations_count
end

#
##################################################
#
state = _get_state

if state && state[:step] == :merge
  merge(state)
else
  sort(state)
  merge(_get_state)
end

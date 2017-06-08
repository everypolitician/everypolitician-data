require 'test_helper'
require_relative '../lib/uuid_map'

describe 'UUID Mapper' do
  let(:tempfile) do
    Tempfile.new(['data-ids', '.csv'])
  end

  let(:tempfile_path) do
    Pathname.new(tempfile.path)
  end

  it "has nothing if the file doesn't exist" do
    UuidMapFile.new(Pathname.new('not/a/file')).mapping.must_be_empty
  end

  it 'has nothing in an empty tempfile' do
    UuidMapFile.new(tempfile_path).mapping.must_be_empty
  end

  it 'has new data after writing' do
    mapper = UuidMapFile.new(tempfile_path)
    data = mapper.mapping
    data.must_be_empty
    data['fred'] = 'uuid-1'
    data['barney'] = 'uuid-2'

    mapper.rewrite(data)

    # read it back in again
    newmap = UuidMapFile.new(tempfile_path)
    newmap.mapping.keys.count.must_equal 2
    newmap.uuid_for('barney').must_equal 'uuid-2'
    newmap.id_for('uuid-1').must_equal 'fred'
  end

  describe '#remap' do
    let(:file)   { new_tempfile }
    let(:mapper) { UuidMapFile.new(file) }
    let(:data)   { { 'fred' => 'uuid-1' } }

    it 'remaps existing UUID to a new id' do
      mapper.rewrite(data)
      mapper.remap('fred', 'freddy')

      newdata = mapper.mapping
      newdata['fred'].must_be_nil
      newdata['freddy'].must_equal 'uuid-1'
    end

    it 'does not remap if old id does not exist' do
      mapper.rewrite(data)

      assert_raises SystemExit do
        mapper.remap('frida', 'freddy')
      end
    end

    it 'does not remap if new id exists' do
      data['barney'] = 'uuid-2'
      mapper.rewrite(data)

      assert_raises SystemExit do
        mapper.remap('fred', 'barney')
      end
    end
  end
end

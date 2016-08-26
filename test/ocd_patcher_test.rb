require 'test_helper'
require_relative '../lib/ocd_patcher'

describe OcdPatcher do
  OcdInstructionMock = Struct.new(:generate, :as_table)

  describe 'generating area names from ids' do
    describe 'a simple addition' do
      let(:row) { { uuid: 1, area_id: 'ocd-division/country:uk/city:london' } }
      let(:ocd_ids) { [{ id: 'ocd-division/country:uk/city:london', name: 'London' }] }
      subject { OcdPatcher.new(row, OcdInstructionMock.new('area', ocd_ids)).patched }

      it 'retains the uuid' do
        subject[:uuid].must_equal 1
      end

      it 'retains the area_id' do
        subject[:area_id].must_equal 'ocd-division/country:uk/city:london'
      end

      it 'adds the area name' do
        subject[:area].must_equal 'London'
      end

      it "doesn't mutate the original row" do
        row[:area].must_be_nil
      end
    end

    it 'generates a warning if area_id is empty' do
      row = { uuid: 1, }
      patcher = OcdPatcher.new(row, OcdInstructionMock.new('area', []))
      result = patcher.patched
      patcher.warnings.must_include '    No area_id given for 1'
    end

    it "generates a warning if it can't match the area_id" do
      row = { uuid: 1, area_id: 'ocd-division/country:uk/city:london' }
      patcher = OcdPatcher.new(row, OcdInstructionMock.new('area', []))
      result = patcher.patched
      patcher.warnings.must_include '    Could not resolve area_id ocd-division/country:uk/city:london for 1'
    end

  end

  it 'tests generating IDs from names' do
    fail 'TODO'
  end
end

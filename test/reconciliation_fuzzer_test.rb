# frozen_string_literal: true

require 'test_helper'

require 'reconciliation'

describe Reconciliation::Fuzzer do
  let(:existing_rows) do
    [{ uuid: 'd50ab88c-8c56-4530-90b2-868adb2b94cd', name: 'Seamus' }]
  end

  let(:incoming_rows) do
    [{ id: '123', name: 'Shamus' }]
  end

  let(:instructions) do
    {
      incoming_field: 'name',
      existing_field: 'name',
    }
  end

  subject { Reconciliation::Fuzzer.new(existing_rows, incoming_rows, instructions) }

  it 'returns matches for the incoming rows' do
    subject.score_all.must_equal [
      {
        incoming: { id: '123', name: 'Shamus' },
        existing: [
          [
            {
              uuid:   'd50ab88c-8c56-4530-90b2-868adb2b94cd',
              name:   'Seamus',
              fuzzit: 'seamus',
            },
            0.6,
            0.8333333333333334,
          ],
        ],
      },
    ]
  end
end

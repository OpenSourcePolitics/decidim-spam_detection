require 'spec_helper'

describe Decidim::SpamDetection::CommandErrors do
  let(:errors) { described_class.new }

  describe '#add' do
    before do
      errors.add :some_error, 'some error description'
    end

    it 'adds the error' do
      expect(errors[:some_error]).to eq(['some error description'])
    end

    it 'adds the same error only once' do
      errors.add :some_error, 'some error description'
      expect(errors[:some_error]).to eq(['some error description'])
    end
  end

  describe '#add_multiple_errors' do
    let(:errors_list) do
      {
        some_error: ['some error description'],
        another_error: ['another error description']
      }
    end

    before do
      errors.add_multiple_errors errors_list
    end

    it 'populates itself with the added errors' do
      expect(errors[:some_error]).to eq(errors_list[:some_error])
      expect(errors[:another_error]).to eq(errors_list[:another_error])
    end
  end

  describe '#each' do
    let(:errors_list) do
      {
        email: ['taken'],
        password: ['blank', 'too short']
      }
    end

    before { errors.add_multiple_errors(errors_list) }

    it 'yields each message for the same key independently' do
      expect { |b| errors.each(&b) }.to yield_control.exactly(3).times
      expect { |b| errors.each(&b) }.to yield_successive_args(
                                          [:email, 'taken'],
                                          [:password, 'blank'],
                                          [:password, 'too short']
                                        )
    end
  end

  describe '#full_messages' do
    before do
      errors.add :attr1, 'has an error'
      errors.add :attr2, 'has an error'
      errors.add :attr2, 'has two errors'
    end

    it "returrns the full messages array" do
      expect(errors.full_messages).to eq ["Attr1 has an error", "Attr2 has an error", "Attr2 has two errors"]
    end

  end
end
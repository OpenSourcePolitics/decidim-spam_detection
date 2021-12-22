require 'spec_helper'

describe Decidim::SpamDetection::Command do
  before do
    stub_const 'DummyCommand', Class.new

    DummyCommand.class_eval do
      prepend Decidim::SpamDetection::Command

      def initialize(input)
        @input = input
      end

      def call
        @input * 2
      end
    end

    stub_const 'FailureDummyCommand', Class.new

    FailureDummyCommand.class_eval do
      prepend Decidim::SpamDetection::Command

      def initialize(input)
        @input = input
      end
    end
  end
  let(:command) { DummyCommand.new(2) }

  describe '.call' do
    before do
      allow(DummyCommand).to receive(:new).and_return(command)
      allow(command).to receive(:call)

      DummyCommand.call 2
    end

    it 'initializes the command' do
      expect(DummyCommand).to have_received(:new)
    end

    it 'calls #call method' do
      expect(command).to have_received(:call)
    end
  end

  describe '#call' do
    let(:failure_command) { FailureDummyCommand.new(2) }

    it 'raises an exception if the method is not defined in the command' do
      expect do
        failure_command.call
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#success?' do
    it 'is true by default' do
      expect(command.call.success?).to be_truthy
    end

    it 'is false if something went wrong' do
      command.errors.add(:some_error, 'some message')
      expect(command.call.success?).to be_falsy
    end

    context 'when call is not called yet' do
      it 'is false by default' do
        expect(command.success?).to be_falsy
      end
    end
  end

  describe '#result' do
    it 'returns the result of command execution' do
      expect(command.call.result).to eq(4)
    end

    context 'when call is not called yet' do
      it 'returns nil' do
        expect(command.result).to be_nil
      end
    end
  end

  describe '#failure?' do
    it 'is false by default' do
      expect(command.call.failure?).to be_falsy
    end

    it 'is true if something went wrong' do
      command.errors.add(:some_error, 'some message')
      expect(command.call.failure?).to be_truthy
    end

    context 'when call is not called yet' do
      it 'is false by default' do
        expect(command.failure?).to be_falsy
      end
    end
  end

  describe '#errors' do
    it 'returns an SimpleCommand::Errors' do
      expect(command.errors).to be_a(Decidim::SpamDetection::CommandErrors)
    end

    context 'with no errors' do
      it 'is empty' do
        expect(command.errors).to be_empty
      end
    end

    context 'with errors' do
      before do
        command.errors.add(:some_error, 'some message')
      end

      it 'has a key with error message' do
        expect(command.errors[:some_error]).to eq(['some message'])
      end
    end
  end
end

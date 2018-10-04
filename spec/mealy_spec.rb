# frozen_string_literal: true

require 'rspec'
require 'simplecov'

SimpleCov.start
require 'mealy'

RSpec.describe Mealy do
  before(:all) { Example = Class.new }
  before { Example.include(described_class) }

  after do
    # if there was a sensible way to "uninclude Mealy" we would do it here.
    # Instead we reset the instance variables that the previous rspec example
    # might have set. This couples the test tightly with the implementation,
    # which is not great but better than not doing anything between tests..
    Example.instance_variable_set(:@start_data, nil)
    Example.instance_variable_set(:@finish_data, nil)
    Example.instance_variable_set(:@transitions, nil)
  end

  let(:fsm_instance) { Example.new }

  describe '.run' do
    context 'without a block' do
      it 'returns an Enumerator' do
        expect(fsm_instance.run([])).to be_an Enumerator
      end
    end
  end

  describe '.execute' do
    it 'returns the result of the finish block' do
      Example.finish { :something }

      expect(fsm_instance.execute([])).to be :something
    end

    context 'when there is emit in user block' do
      it 'doesn\'t raise error' do
        Example.initial_state(:start) { emit(:blah) }

        expect { fsm_instance.execute([]) }.not_to raise_error
      end
    end
  end

  describe 'running' do
    context 'with .initial_state user block' do
      it 'fires user block once' do
        expect do |b|
          Example.initial_state(:start, &b)

          fsm_instance.execute([])
        end.to yield_control
      end
    end

    context 'when transitioning away from initial state' do
      context 'with matching input' do
        context 'with user block' do
          it 'fires user block' do
            expect do |b|
              Example.class_eval do
                initial_state(:start)
                transition(from: :start, to: :end, on: 1, &b)
              end

              fsm_instance.execute([1])
            end.to yield_control
          end
        end
      end

      context 'with non matching input' do
        it 'raises Mealy::UnexpectedTokenError' do
          Example.class_eval do
            initial_state :start
            transition from: :start, to: :end, on: 1
          end

          expect do
            fsm_instance.execute([2])
          end.to raise_error(Mealy::UnexpectedTokenError)
        end
      end
    end

    context 'when in normal state transitions' do
      context 'with ANY label' do
        context 'with user block' do
          it 'fires user block' do
            expect do |b|
              Example.class_eval do
                initial_state :start
                transition from: :start, to: :mid
                transition(from: :mid, to: :end, &b)
              end

              fsm_instance.execute([1, 2])
            end.to yield_control
          end
        end
      end

      context 'with matching input' do
        context 'with user block' do
          it 'fires user block' do
            expect do |b|
              Example.class_eval do
                initial_state(:start)
                transition from: :start, to: :mid, on: 1
                transition(from: :mid, to: :end, on: 2, &b)
              end

              fsm_instance.execute([1, 2])
            end.to yield_control
          end

          it 'runs user blocks in instance context' do
            Example.initial_state(:start) { @something = :defined }

            fsm_instance.execute([])
            something = fsm_instance.instance_variable_get(:@something)
            expect(something).to be :defined
          end

          it 'passes the token, the to and from states to user block' do
            Example.class_eval do
              initial_state(:start)

              transition from: :start, to: :end, on: 1 do |token, from, to|
                @token = token
                @from = from
                @to = to
              end

              attr_reader :token, :to, :from
            end

            fsm_instance.execute([1])

            expect(fsm_instance.token).to be(1)
            expect(fsm_instance.from).to be(:start)
            expect(fsm_instance.to).to be(:end)
          end

          it 'emits from the user block' do
            Example.class_eval do
              initial_state(:start)

              transition from: :start, to: :end, on: 1 do
                emit(1)
                emit(2)
                emit(3)
              end
            end

            expect do |b|
              fsm_instance.run([1], &b)
            end.to yield_successive_args(1, 2, 3)
          end
        end
      end

      context 'with non matching input' do
        it 'raises Mealy::UnexpectedTokenError' do
          Example.class_eval do
            initial_state :start
            transition from: :start, to: :mid, on: 1
            transition from: :mid, to: :end, on: 2
          end

          expect do
            fsm_instance.execute([1, 1])
          end.to raise_error(Mealy::UnexpectedTokenError)
        end
      end
    end

    context 'when input ends prematurely' do
      it 'runs without error' do
        Example.class_eval do
          initial_state :start
          transition from: :start, to: :mid, on: 1
          transition from: :mid, to: :end, on: 2
        end

        expect do
          fsm_instance.execute([1])
        end.not_to raise_error
      end
    end

    context 'when in a state loop' do
      it 'fires the user action on each loop' do
        expect do |b|
          Example.class_eval do
            initial_state :start
            read(state: :start, on: 1, &b)
          end

          fsm_instance.execute([1] * 10)
        end.to yield_control.exactly(10).times
      end
    end

    context 'when at the end' do
      context 'when finish is set with user block' do
        it 'calls the user block' do
          expect do |b|
            Example.finish(&b)

            fsm_instance.execute([])
          end.to yield_control
        end
      end
    end
  end
end

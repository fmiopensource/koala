module AASM
  module Persistence
    module OhmPersistence
      # This method:
      #
      # * extends the model with ClassMethods
      # * includes InstanceMethods
      #
      # Unless the corresponding methods are already defined, it includes
      # * ReadState
      # * WriteState
      # * WriteStateWithoutPersistence
      #
      def self.included(base)
        base.extend AASM::Persistence::OhmPersistence::ClassMethods 
        base.send(:include, AASM::Persistence::OhmPersistence::InstanceMethods)
        base.send(:include, AASM::Persistence::OhmPersistence::ReadState) unless base.method_defined?(:aasm_read_state)
        base.send(:include, AASM::Persistence::OhmPersistence::WriteState) unless base.method_defined?(:aasm_write_state)
        base.send(:include, AASM::Persistence::OhmPersistence::WriteStateWithoutPersistence) unless base.method_defined?(:aasm_write_state_without_persistence)
      end

      module ClassMethods
        # Maps to the aasm_column in the database.  Deafults to "aasm_state".  You can write:
        #
        #   class Foo < Ohm::Model
        #     include AASM
        #     
        #     attribute :status
        #     aasm_column :status
        #   end
        #
        # This method is both a getter and a setter
        def aasm_column(column_name=nil)
          if column_name
            AASM::StateMachine[self].config.column = column_name.to_sym
            # @aasm_column = column_name.to_sym
          else
            AASM::StateMachine[self].config.column ||= :aasm_state
            # @aasm_column ||= :aasm_state
          end
          # @aasm_column
          AASM::StateMachine[self].config.column
        end

        # TODO: Not yet implemented
        
        # def find_in_state(number, state, *args)
        # end
        # 
        # def count_in_state(state, *args)
        # end
        # 
        # def calculate_in_state(state, *args)
        # end
      end

      module InstanceMethods

        # Returns the current aasm_state of the object.
        #
        # Internally just calls <tt>aasm_read_state</tt>
        #
        #   foo = Foo[1]
        #   foo.aasm_current_state # => :pending
        #   foo.next_state!
        #   foo.aasm_current_state # => :next_state
        #
        def aasm_current_state
          @current_state = aasm_read_state
        end
      end

      module WriteStateWithoutPersistence
        # Writes <tt>state</tt> to the state column, but does not persist it to the database
        #
        #   foo = Foo[1]
        #   foo.aasm_current_state # => :opened
        #   foo.close
        #   foo.aasm_current_state # => :closed
        #   Foo[1].aasm_current_state # => :opened
        #   foo.save
        #   foo.aasm_current_state # => :closed
        #   Foo[1].aasm_current_state # => :closed
        #
        # NOTE: intended to be called from an event
        def aasm_write_state_without_persistence(state)
          update_attributes(self.class.aasm_column.to_sym => state.to_s)
        end
      end

      module WriteState
        # Writes <tt>state</tt> to the state column and persists it to the database
        # using update_attribute (which bypasses validation)
        #
        #   foo = Foo[1]
        #   foo.aasm_current_state # => :opened
        #   foo.close!
        #   foo.aasm_current_state # => :closed
        #   Foo[1].aasm_current_state # => :closed
        #
        # NOTE: intended to be called from an event
        def aasm_write_state(state)
          old_value = self.class.aasm_column
          update(self.class.aasm_column.to_sym => state.to_s)

          unless self.valid?
            update(self.class.aasm_column.to_sym => old_value.to_s)
            return false
          end

          true
        end
      end

      module ReadState

        # Returns the value of the aasm_column - called from <tt>aasm_current_state</tt>
        #
        # If it's a new record, and the aasm state column is blank it returns the initial state:
        #
        #   class Foo < Ohm::Model
        #     include AASM
        #     aasm_column :status
        #     aasm_state :opened
        #     aasm_state :closed
        #   end
        #
        #   foo = Foo.new
        #   foo.current_state # => :opened
        #   foo.close
        #   foo.current_state # => :closed
        #
        #   foo = Foo[1]
        #   foo.current_state # => :opened
        #   foo.aasm_state = nil
        #   foo.current_state # => nil
        #
        # NOTE: intended to be called from an event
        #
        # This allows for nil aasm states - be sure to add validation to your model
        def aasm_read_state
          if new?
            send(self.class.aasm_column).blank? ? aasm_determine_state_name(self.class.aasm_initial_state) : send(self.class.aasm_column).to_sym
          else
            send(self.class.aasm_column).nil? ? nil : send(self.class.aasm_column).to_sym
          end
        end
      end
      
    end
  end
end
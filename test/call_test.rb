require "test_helper"

# DISCUSS: do we need this test?
class CallTest < Minitest::Spec
  describe "::call" do
    class Create < Trailblazer::Operation
      def inspect
        "#{@skills.inspect}"
      end
    end

    it { Create.().must_be_instance_of Trailblazer::Operation::Result }

    it { Create.({}).inspect.must_equal %{<Skill {} {\"params\"=>{}} {\"pipetree\"=>[>>New,>>Call,Result::Build]}>} }
    it { Create.(name: "Jacob").inspect.must_equal %{<Skill {} {\"params\"=>{:name=>\"Jacob\"}} {\"pipetree\"=>[>>New,>>Call,Result::Build]}>} }
    it { Create.({ name: "Jacob" }, { policy: Object }).inspect.must_equal %{<Skill {} {:policy=>Object, \"params\"=>{:name=>\"Jacob\"}} {\"pipetree\"=>[>>New,>>Call,Result::Build]}>} }

    #---
    # success?
    class Update < Trailblazer::Operation
      self.& ->(input, options) { input["params"] }, after: Call
    end

    it { Update.(true).success?.must_equal true }
    it { Update.(false).success?.must_equal false }
  end
end


module IntegrationTestHelpers
  def with_provider_stub(target,method,value)
    original=target.method(method)
    own=target.singleton_class.instance_methods(false).include?(method)
    target.define_singleton_method(method){|*args|value.respond_to?(:call) ? value.call(*args) : value}
    yield
  ensure
    if own
      target.define_singleton_method(method,original)
    else
      target.singleton_class.remove_method(method)
    end
  end
end

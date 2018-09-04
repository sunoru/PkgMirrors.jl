module Types

import Base: ==

mutable struct Mirror
    name::String
    url::String
end

==(a::Mirror, b::Mirror) = a.name == b.name && a.url == b.url

mutable struct Finalizer end
FINALIZER = Finalizer()

end

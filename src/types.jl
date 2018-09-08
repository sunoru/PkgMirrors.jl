module Types

import Base: ==

mutable struct PkgMirror
    name::String
    url::String
end

==(a::PkgMirror, b::PkgMirror) = a.name == b.name && a.url == b.url

mutable struct Finalizer end
FINALIZER = Finalizer()

end

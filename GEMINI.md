*. Try to use `struct` instead of `class` when you can.
*. Try to import `FoundationEssentials` if you can like so:

```swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
```

* Regularly run `swift build` to see that it compiles.
* Do not use `NSLock` use `actor` when possible.
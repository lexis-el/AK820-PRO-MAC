import SwiftUI

/// Same as `@State`. In recent SDKs `@State` is a compiler macro whose plugin ships only with Xcode,
/// so this wrapper uses the `State` type directly and the app builds with just the Command Line Tools.
@propertyWrapper
struct Local<Value>: DynamicProperty {
    private var state: SwiftUI.State<Value>
    init(wrappedValue: Value) { state = SwiftUI.State(initialValue: wrappedValue) }
    var wrappedValue: Value {
        get { state.wrappedValue }
        nonmutating set { state.wrappedValue = newValue }
    }
    var projectedValue: Binding<Value> { state.projectedValue }
}

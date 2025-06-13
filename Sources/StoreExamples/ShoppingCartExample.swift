import SwiftUI
import Store

// MARK: - Models

public struct Product: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let price: Double
    public let imageSystemName: String
    public let category: String
    public let inStock: Bool
    
    public init(
        id: String,
        name: String,
        description: String,
        price: Double,
        imageSystemName: String,
        category: String,
        inStock: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.imageSystemName = imageSystemName
        self.category = category
        self.inStock = inStock
    }
}

public struct CartItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let product: Product
    public var quantity: Int
    
    public var subtotal: Double {
        product.price * Double(quantity)
    }
    
    public init(product: Product, quantity: Int = 1) {
        self.id = product.id
        self.product = product
        self.quantity = quantity
    }
}

// MARK: - State & Actions

public struct ShoppingCartState: Equatable, Sendable {
    public var products: [Product]
    public var cartItems: [CartItem]
    public var selectedCategory: String?
    public var appliedCoupon: String?
    public var discountPercentage: Double
    public var isProcessingCheckout: Bool
    public var checkoutError: String?
    public var orderComplete: Bool
    
    public var subtotal: Double {
        cartItems.reduce(0) { $0 + $1.subtotal }
    }
    
    public var discount: Double {
        subtotal * (discountPercentage / 100)
    }
    
    public var tax: Double {
        (subtotal - discount) * 0.08 // 8% tax
    }
    
    public var total: Double {
        subtotal - discount + tax
    }
    
    public var itemCount: Int {
        cartItems.reduce(0) { $0 + $1.quantity }
    }
    
    public var filteredProducts: [Product] {
        guard let category = selectedCategory else { return products }
        return products.filter { $0.category == category }
    }
    
    public var categories: [String] {
        Array(Set(products.map { $0.category })).sorted()
    }
    
    public init(products: [Product] = []) {
        self.products = products
        self.cartItems = []
        self.selectedCategory = nil
        self.appliedCoupon = nil
        self.discountPercentage = 0
        self.isProcessingCheckout = false
        self.checkoutError = nil
        self.orderComplete = false
    }
}

public enum ShoppingCartAction: Equatable, Sendable {
    case addToCart(Product)
    case removeFromCart(productId: String)
    case updateQuantity(productId: String, quantity: Int)
    case incrementQuantity(productId: String)
    case decrementQuantity(productId: String)
    case clearCart
    case selectCategory(String?)
    case applyCoupon(String)
    case removeCoupon
    case checkout
    case checkoutCompleted(success: Bool, error: String?)
    case resetCheckout
}

// MARK: - Reducer

public func shoppingCartReducer(state: inout ShoppingCartState, action: ShoppingCartAction) {
    switch action {
    case .addToCart(let product):
        if let index = state.cartItems.firstIndex(where: { $0.product.id == product.id }) {
            state.cartItems[index].quantity += 1
        } else {
            state.cartItems.append(CartItem(product: product))
        }
        
    case .removeFromCart(let productId):
        state.cartItems.removeAll { $0.product.id == productId }
        
    case .updateQuantity(let productId, let quantity):
        if quantity <= 0 {
            state.cartItems.removeAll { $0.product.id == productId }
        } else if let index = state.cartItems.firstIndex(where: { $0.product.id == productId }) {
            state.cartItems[index].quantity = quantity
        }
        
    case .incrementQuantity(let productId):
        if let index = state.cartItems.firstIndex(where: { $0.product.id == productId }) {
            state.cartItems[index].quantity += 1
        }
        
    case .decrementQuantity(let productId):
        if let index = state.cartItems.firstIndex(where: { $0.product.id == productId }) {
            if state.cartItems[index].quantity > 1 {
                state.cartItems[index].quantity -= 1
            } else {
                state.cartItems.remove(at: index)
            }
        }
        
    case .clearCart:
        state.cartItems = []
        state.appliedCoupon = nil
        state.discountPercentage = 0
        
    case .selectCategory(let category):
        state.selectedCategory = category
        
    case .applyCoupon(let code):
        // Simple coupon validation
        switch code.uppercased() {
        case "SAVE10":
            state.appliedCoupon = code
            state.discountPercentage = 10
        case "SAVE20":
            state.appliedCoupon = code
            state.discountPercentage = 20
        case "HALFOFF":
            state.appliedCoupon = code
            state.discountPercentage = 50
        default:
            state.appliedCoupon = nil
            state.discountPercentage = 0
        }
        
    case .removeCoupon:
        state.appliedCoupon = nil
        state.discountPercentage = 0
        
    case .checkout:
        state.isProcessingCheckout = true
        state.checkoutError = nil
        
    case .checkoutCompleted(let success, let error):
        state.isProcessingCheckout = false
        if success {
            state.orderComplete = true
            state.cartItems = []
            state.appliedCoupon = nil
            state.discountPercentage = 0
        } else {
            state.checkoutError = error ?? "Checkout failed"
        }
        
    case .resetCheckout:
        state.orderComplete = false
        state.checkoutError = nil
    }
}

// MARK: - Effects

public func shoppingCartEffects(
    action: ShoppingCartAction,
    state: ShoppingCartState
) async -> ShoppingCartAction? {
    switch action {
    case .checkout where !state.cartItems.isEmpty:
        // Simulate checkout process
        do {
            try await Task.sleep(for: .seconds(2))
            
            // Simulate random success/failure
            let success = Double.random(in: 0...1) > 0.2
            if success {
                return .checkoutCompleted(success: true, error: nil)
            } else {
                return .checkoutCompleted(success: false, error: "Payment processing failed")
            }
        } catch {
            return .checkoutCompleted(success: false, error: "Checkout cancelled")
        }
        
    default:
        return nil
    }
}

// MARK: - Sample Data

public let sampleProducts: [Product] = [
    Product(id: "1", name: "iPhone 15 Pro", description: "Latest iPhone with titanium design", price: 999.00, imageSystemName: "iphone", category: "Electronics"),
    Product(id: "2", name: "MacBook Pro 14\"", description: "M3 Pro chip, 18GB RAM", price: 1999.00, imageSystemName: "laptopcomputer", category: "Electronics"),
    Product(id: "3", name: "AirPods Pro", description: "Active noise cancellation", price: 249.00, imageSystemName: "airpodspro", category: "Electronics"),
    Product(id: "4", name: "iPad Air", description: "10.9-inch Liquid Retina display", price: 599.00, imageSystemName: "ipad", category: "Electronics"),
    Product(id: "5", name: "Apple Watch Series 9", description: "Advanced health tracking", price: 399.00, imageSystemName: "applewatch", category: "Electronics"),
    Product(id: "6", name: "Running Shoes", description: "Comfortable athletic footwear", price: 89.99, imageSystemName: "figure.run", category: "Sports"),
    Product(id: "7", name: "Yoga Mat", description: "Non-slip exercise mat", price: 29.99, imageSystemName: "figure.yoga", category: "Sports"),
    Product(id: "8", name: "Water Bottle", description: "Insulated 32oz bottle", price: 24.99, imageSystemName: "waterbottle", category: "Sports"),
    Product(id: "9", name: "Backpack", description: "Durable hiking backpack", price: 79.99, imageSystemName: "backpack", category: "Outdoors"),
    Product(id: "10", name: "Tent", description: "2-person camping tent", price: 149.99, imageSystemName: "tent", category: "Outdoors"),
    Product(id: "11", name: "Out of Stock Item", description: "This item is not available", price: 99.99, imageSystemName: "xmark.circle", category: "Electronics", inStock: false),
]

// MARK: - Store Creation

@MainActor
public func createShoppingCartStore(products: [Product] = sampleProducts) -> Store<ShoppingCartState, ShoppingCartAction> {
    Store(
        initialState: ShoppingCartState(products: products),
        reducer: shoppingCartReducer,
        effects: [shoppingCartEffects]
    )
}

// MARK: - SwiftUI Views

public struct ShoppingCartView: View {
    let store: Store<ShoppingCartState, ShoppingCartAction>
    @State private var couponCode: String = ""
    
    public init(store: Store<ShoppingCartState, ShoppingCartAction>) {
        self.store = store
    }
    
    public var body: some View {
        NavigationSplitView {
            ProductListView(store: store)
        } detail: {
            CartDetailView(store: store, couponCode: $couponCode)
        }
        #if os(iOS)
        .navigationSplitViewStyle(.balanced)
        #endif
    }
}

struct ProductListView: View {
    let store: Store<ShoppingCartState, ShoppingCartAction>
    
    var body: some View {
        List {
            // Category Filter
            Section {
                Picker("Category", selection: .init(
                    get: { store.currentState.selectedCategory },
                    set: { newValue in Task { await store.dispatch(.selectCategory(newValue)) } }
                )) {
                    Text("All").tag(nil as String?)
                    ForEach(store.currentState.categories, id: \.self) { category in
                        Text(category).tag(category as String?)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Products
            Section("Products") {
                ForEach(store.currentState.filteredProducts) { product in
                    ProductRow(product: product, store: store)
                }
            }
        }
        .navigationTitle("Shop")
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}

struct ProductRow: View {
    let product: Product
    let store: Store<ShoppingCartState, ShoppingCartAction>
    
    var cartItem: CartItem? {
        store.currentState.cartItems.first { $0.product.id == product.id }
    }
    
    var body: some View {
        HStack {
            Image(systemName: product.imageSystemName)
                .font(.largeTitle)
                .foregroundColor(.blue)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(product.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            if !product.inStock {
                Text("Out of Stock")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let cartItem {
                HStack(spacing: 12) {
                    Button(action: {
                        Task { await store.dispatch(.decrementQuantity(productId: product.id)) }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    
                    Text("\(cartItem.quantity)")
                        .font(.headline)
                        .frame(minWidth: 30)
                    
                    Button(action: {
                        Task { await store.dispatch(.incrementQuantity(productId: product.id)) }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            } else {
                Button(action: {
                    Task { await store.dispatch(.addToCart(product)) }
                }) {
                    Text("Add")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CartDetailView: View {
    let store: Store<ShoppingCartState, ShoppingCartAction>
    @Binding var couponCode: String
    
    var body: some View {
        if store.currentState.orderComplete {
            OrderCompleteView(store: store)
        } else {
            VStack {
                if store.currentState.cartItems.isEmpty {
                    EmptyCartView()
                } else {
                    List {
                        Section("Cart Items (\(store.currentState.itemCount))") {
                            ForEach(store.currentState.cartItems) { item in
                                CartItemRow(item: item, store: store)
                            }
                        }
                        
                        Section("Coupon") {
                            if let appliedCoupon = store.currentState.appliedCoupon {
                                HStack {
                                    Text("Applied: \(appliedCoupon)")
                                        .foregroundColor(.green)
                                    Spacer()
                                    Button("Remove") {
                                        Task { await store.dispatch(.removeCoupon) }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            } else {
                                HStack {
                                    TextField("Enter coupon code", text: $couponCode)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Apply") {
                                        Task { 
                                            await store.dispatch(.applyCoupon(couponCode))
                                            if store.currentState.appliedCoupon != nil {
                                                couponCode = ""
                                            }
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(couponCode.isEmpty)
                                }
                            }
                            Text("Try: SAVE10, SAVE20, or HALFOFF")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Section("Order Summary") {
                            HStack {
                                Text("Subtotal")
                                Spacer()
                                Text("$\(store.currentState.subtotal, specifier: "%.2f")")
                            }
                            
                            if store.currentState.discount > 0 {
                                HStack {
                                    Text("Discount (\(Int(store.currentState.discountPercentage))%)")
                                        .foregroundColor(.green)
                                    Spacer()
                                    Text("-$\(store.currentState.discount, specifier: "%.2f")")
                                        .foregroundColor(.green)
                                }
                            }
                            
                            HStack {
                                Text("Tax (8%)")
                                Spacer()
                                Text("$\(store.currentState.tax, specifier: "%.2f")")
                            }
                            
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                Spacer()
                                Text("$\(store.currentState.total, specifier: "%.2f")")
                                    .font(.headline)
                            }
                        }
                    }
                    
                    VStack(spacing: 12) {
                        if let error = store.currentState.checkoutError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: {
                            Task { await store.dispatch(.checkout) }
                        }) {
                            if store.currentState.isProcessingCheckout {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .foregroundColor(.white)
                            } else {
                                Text("Checkout")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(store.currentState.isProcessingCheckout)
                        
                        Button("Clear Cart") {
                            Task { await store.dispatch(.clearCart) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("Shopping Cart")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let store: Store<ShoppingCartState, ShoppingCartAction>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.product.name)
                        .font(.headline)
                    Text("$\(item.product.price, specifier: "%.2f") each")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("$\(item.subtotal, specifier: "%.2f")")
                    .font(.headline)
            }
            
            HStack {
                Button(action: {
                    Task { await store.dispatch(.removeFromCart(productId: item.product.id)) }
                }) {
                    Text("Remove")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task { await store.dispatch(.decrementQuantity(productId: item.product.id)) }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    
                    Text("\(item.quantity)")
                        .font(.headline)
                        .frame(minWidth: 30)
                    
                    Button(action: {
                        Task { await store.dispatch(.incrementQuantity(productId: item.product.id)) }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyCartView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Your cart is empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add items to get started")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OrderCompleteView: View {
    let store: Store<ShoppingCartState, ShoppingCartAction>
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Order Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Thank you for your purchase")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Button("Continue Shopping") {
                Task { await store.dispatch(.resetCheckout) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Shopping Cart") {
    ShoppingCartView(store: createShoppingCartStore())
}
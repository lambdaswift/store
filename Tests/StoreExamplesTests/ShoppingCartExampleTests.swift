import Testing
import Foundation
@testable import StoreExamples
@testable import Store

@Suite("Shopping Cart Example Tests")
struct ShoppingCartExampleTests {
    
    @Test("Shopping cart initial state")
    @MainActor
    func testInitialState() async {
        let store = createShoppingCartStore()
        #expect(store.currentState.cartItems.isEmpty)
        #expect(store.currentState.products.count == 11)
        #expect(store.currentState.selectedCategory == nil)
        #expect(store.currentState.appliedCoupon == nil)
        #expect(store.currentState.discountPercentage == 0)
        #expect(store.currentState.isProcessingCheckout == false)
        #expect(store.currentState.checkoutError == nil)
        #expect(store.currentState.orderComplete == false)
        #expect(store.currentState.subtotal == 0)
        #expect(store.currentState.discount == 0)
        #expect(store.currentState.tax == 0)
        #expect(store.currentState.total == 0)
        #expect(store.currentState.itemCount == 0)
    }
    
    @Test("Add products to cart")
    @MainActor
    func testAddToCart() async {
        let store = createShoppingCartStore()
        let product1 = store.currentState.products[0]
        let product2 = store.currentState.products[1]
        
        // Add first product
        await store.dispatch(.addToCart(product1))
        #expect(store.currentState.cartItems.count == 1)
        #expect(store.currentState.cartItems[0].product.id == product1.id)
        #expect(store.currentState.cartItems[0].quantity == 1)
        #expect(store.currentState.itemCount == 1)
        
        // Add same product again - should increase quantity
        await store.dispatch(.addToCart(product1))
        #expect(store.currentState.cartItems.count == 1)
        #expect(store.currentState.cartItems[0].quantity == 2)
        #expect(store.currentState.itemCount == 2)
        
        // Add different product
        await store.dispatch(.addToCart(product2))
        #expect(store.currentState.cartItems.count == 2)
        #expect(store.currentState.itemCount == 3)
    }
    
    @Test("Remove products from cart")
    @MainActor
    func testRemoveFromCart() async {
        let store = createShoppingCartStore()
        let product1 = store.currentState.products[0]
        let product2 = store.currentState.products[1]
        
        // Add products
        await store.dispatch(.addToCart(product1))
        await store.dispatch(.addToCart(product2))
        #expect(store.currentState.cartItems.count == 2)
        
        // Remove first product
        await store.dispatch(.removeFromCart(productId: product1.id))
        #expect(store.currentState.cartItems.count == 1)
        #expect(store.currentState.cartItems[0].product.id == product2.id)
        
        // Remove non-existent product - should do nothing
        await store.dispatch(.removeFromCart(productId: "non-existent"))
        #expect(store.currentState.cartItems.count == 1)
        
        // Remove second product
        await store.dispatch(.removeFromCart(productId: product2.id))
        #expect(store.currentState.cartItems.isEmpty)
    }
    
    @Test("Update product quantity")
    @MainActor
    func testUpdateQuantity() async {
        let store = createShoppingCartStore()
        let product = store.currentState.products[0]
        
        // Add product
        await store.dispatch(.addToCart(product))
        
        // Update quantity
        await store.dispatch(.updateQuantity(productId: product.id, quantity: 5))
        #expect(store.currentState.cartItems[0].quantity == 5)
        #expect(store.currentState.itemCount == 5)
        
        // Update to zero - should remove item
        await store.dispatch(.updateQuantity(productId: product.id, quantity: 0))
        #expect(store.currentState.cartItems.isEmpty)
        
        // Update non-existent product - should do nothing
        await store.dispatch(.updateQuantity(productId: "non-existent", quantity: 3))
        #expect(store.currentState.cartItems.isEmpty)
    }
    
    @Test("Increment and decrement quantity")
    @MainActor
    func testIncrementDecrement() async {
        let store = createShoppingCartStore()
        let product = store.currentState.products[0]
        
        // Add product
        await store.dispatch(.addToCart(product))
        #expect(store.currentState.cartItems[0].quantity == 1)
        
        // Increment
        await store.dispatch(.incrementQuantity(productId: product.id))
        #expect(store.currentState.cartItems[0].quantity == 2)
        
        await store.dispatch(.incrementQuantity(productId: product.id))
        #expect(store.currentState.cartItems[0].quantity == 3)
        
        // Decrement
        await store.dispatch(.decrementQuantity(productId: product.id))
        #expect(store.currentState.cartItems[0].quantity == 2)
        
        await store.dispatch(.decrementQuantity(productId: product.id))
        #expect(store.currentState.cartItems[0].quantity == 1)
        
        // Decrement when quantity is 1 - should remove item
        await store.dispatch(.decrementQuantity(productId: product.id))
        #expect(store.currentState.cartItems.isEmpty)
        
        // Increment/decrement non-existent product - should do nothing
        await store.dispatch(.incrementQuantity(productId: "non-existent"))
        await store.dispatch(.decrementQuantity(productId: "non-existent"))
        #expect(store.currentState.cartItems.isEmpty)
    }
    
    @Test("Clear cart")
    @MainActor
    func testClearCart() async {
        let store = createShoppingCartStore()
        
        // Add products and apply coupon
        await store.dispatch(.addToCart(store.currentState.products[0]))
        await store.dispatch(.addToCart(store.currentState.products[1]))
        await store.dispatch(.applyCoupon("SAVE10"))
        
        #expect(store.currentState.cartItems.count == 2)
        #expect(store.currentState.appliedCoupon == "SAVE10")
        #expect(store.currentState.discountPercentage == 10)
        
        // Clear cart
        await store.dispatch(.clearCart)
        #expect(store.currentState.cartItems.isEmpty)
        #expect(store.currentState.appliedCoupon == nil)
        #expect(store.currentState.discountPercentage == 0)
    }
    
    @Test("Category filtering")
    @MainActor
    func testCategoryFiltering() async {
        let store = createShoppingCartStore()
        
        // Check categories
        let categories = store.currentState.categories
        #expect(categories.contains("Electronics"))
        #expect(categories.contains("Sports"))
        #expect(categories.contains("Outdoors"))
        
        // No filter - all products
        #expect(store.currentState.filteredProducts.count == store.currentState.products.count)
        
        // Filter by Electronics
        await store.dispatch(.selectCategory("Electronics"))
        let electronicsProducts = store.currentState.filteredProducts
        #expect(electronicsProducts.allSatisfy { $0.category == "Electronics" })
        #expect(electronicsProducts.count == 6)
        
        // Filter by Sports
        await store.dispatch(.selectCategory("Sports"))
        let sportsProducts = store.currentState.filteredProducts
        #expect(sportsProducts.allSatisfy { $0.category == "Sports" })
        #expect(sportsProducts.count == 3)
        
        // Clear filter
        await store.dispatch(.selectCategory(nil))
        #expect(store.currentState.filteredProducts.count == store.currentState.products.count)
    }
    
    @Test("Coupon application")
    @MainActor
    func testCouponApplication() async {
        let store = createShoppingCartStore()
        
        // Apply SAVE10 coupon
        await store.dispatch(.applyCoupon("SAVE10"))
        #expect(store.currentState.appliedCoupon == "SAVE10")
        #expect(store.currentState.discountPercentage == 10)
        
        // Apply SAVE20 coupon (should replace)
        await store.dispatch(.applyCoupon("SAVE20"))
        #expect(store.currentState.appliedCoupon == "SAVE20")
        #expect(store.currentState.discountPercentage == 20)
        
        // Apply HALFOFF coupon
        await store.dispatch(.applyCoupon("HALFOFF"))
        #expect(store.currentState.appliedCoupon == "HALFOFF")
        #expect(store.currentState.discountPercentage == 50)
        
        // Apply invalid coupon
        await store.dispatch(.applyCoupon("INVALID"))
        #expect(store.currentState.appliedCoupon == nil)
        #expect(store.currentState.discountPercentage == 0)
        
        // Apply valid coupon again
        await store.dispatch(.applyCoupon("SAVE10"))
        #expect(store.currentState.appliedCoupon == "SAVE10")
        
        // Remove coupon
        await store.dispatch(.removeCoupon)
        #expect(store.currentState.appliedCoupon == nil)
        #expect(store.currentState.discountPercentage == 0)
    }
    
    @Test("Price calculations")
    @MainActor
    func testPriceCalculations() async {
        let store = createShoppingCartStore()
        let product1 = Product(id: "test1", name: "Test 1", description: "", price: 100.00, imageSystemName: "cart", category: "Test")
        let product2 = Product(id: "test2", name: "Test 2", description: "", price: 50.00, imageSystemName: "cart", category: "Test")
        
        // Add products
        await store.dispatch(.addToCart(product1))
        await store.dispatch(.addToCart(product2))
        await store.dispatch(.updateQuantity(productId: product1.id, quantity: 2))
        
        // Check subtotal: (100 * 2) + (50 * 1) = 250
        #expect(store.currentState.subtotal == 250.00)
        #expect(store.currentState.discount == 0)
        #expect(store.currentState.tax == 20.00) // 8% of 250
        #expect(store.currentState.total == 270.00) // 250 + 20
        
        // Apply 10% discount
        await store.dispatch(.applyCoupon("SAVE10"))
        #expect(store.currentState.discount == 25.00) // 10% of 250
        #expect(store.currentState.tax == 18.00) // 8% of 225
        #expect(store.currentState.total == 243.00) // 250 - 25 + 18
        
        // Apply 50% discount
        await store.dispatch(.applyCoupon("HALFOFF"))
        #expect(store.currentState.discount == 125.00) // 50% of 250
        #expect(store.currentState.tax == 10.00) // 8% of 125
        #expect(store.currentState.total == 135.00) // 250 - 125 + 10
    }
    
    @Test("Checkout process")
    @MainActor
    func testCheckout() async throws {
        let store = createShoppingCartStore()
        
        // Add product
        await store.dispatch(.addToCart(store.currentState.products[0]))
        
        // Start checkout
        await store.dispatch(.checkout)
        #expect(store.currentState.isProcessingCheckout == true)
        
        // Wait for checkout to complete
        await store.waitForEffects()
        
        #expect(store.currentState.isProcessingCheckout == false)
        // Either success or failure
        if store.currentState.orderComplete {
            #expect(store.currentState.cartItems.isEmpty)
            #expect(store.currentState.appliedCoupon == nil)
            #expect(store.currentState.discountPercentage == 0)
        } else {
            #expect(store.currentState.checkoutError != nil)
        }
    }
    
    @Test("Checkout with empty cart")
    @MainActor
    func testCheckoutEmptyCart() async {
        let store = createShoppingCartStore()
        
        // Try to checkout with empty cart
        await store.dispatch(.checkout)
        #expect(store.currentState.isProcessingCheckout == true)
        
        // Effect should not run for empty cart
        await store.waitForEffects()
        #expect(store.currentState.isProcessingCheckout == true) // Still true, no effect ran
    }
    
    @Test("Reset checkout")
    @MainActor
    func testResetCheckout() async {
        let store = createShoppingCartStore()
        
        // Simulate completed order
        await store.dispatch(.checkoutCompleted(success: true, error: nil))
        #expect(store.currentState.orderComplete == true)
        
        // Reset
        await store.dispatch(.resetCheckout)
        #expect(store.currentState.orderComplete == false)
        #expect(store.currentState.checkoutError == nil)
    }
    
    @Test("Cart item model")
    func testCartItemModel() {
        let product = Product(id: "1", name: "Test", description: "", price: 10.00, imageSystemName: "cart", category: "Test")
        let cartItem = CartItem(product: product, quantity: 5)
        
        #expect(cartItem.id == "1")
        #expect(cartItem.product.id == "1")
        #expect(cartItem.quantity == 5)
        #expect(cartItem.subtotal == 50.00)
    }
    
    @Test("Product model")
    func testProductModel() {
        let product = Product(
            id: "test",
            name: "Test Product",
            description: "Test Description",
            price: 99.99,
            imageSystemName: "cart",
            category: "Test Category",
            inStock: false
        )
        
        #expect(product.id == "test")
        #expect(product.name == "Test Product")
        #expect(product.description == "Test Description")
        #expect(product.price == 99.99)
        #expect(product.imageSystemName == "cart")
        #expect(product.category == "Test Category")
        #expect(product.inStock == false)
    }
    
    @Test("Reducer directly")
    func testReducerDirectly() {
        var state = ShoppingCartState(products: sampleProducts)
        let product = sampleProducts[0]
        
        // Add to cart
        shoppingCartReducer(state: &state, action: .addToCart(product))
        #expect(state.cartItems.count == 1)
        #expect(state.cartItems[0].quantity == 1)
        
        // Increment quantity
        shoppingCartReducer(state: &state, action: .incrementQuantity(productId: product.id))
        #expect(state.cartItems[0].quantity == 2)
        
        // Apply coupon
        shoppingCartReducer(state: &state, action: .applyCoupon("SAVE20"))
        #expect(state.discountPercentage == 20)
        
        // Checkout
        shoppingCartReducer(state: &state, action: .checkout)
        #expect(state.isProcessingCheckout == true)
    }
}
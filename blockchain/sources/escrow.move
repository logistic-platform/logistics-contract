/// Payment Escrow for COD (Cash on Delivery) Shipments
/// Holds payment until delivery is confirmed
module logistics::escrow {
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;
    use sui::clock::{Self, Clock};

    // ==================== Error Codes ====================
    const EInsufficientFunds: u64 = 1;
    const EEscrowNotFound: u64 = 2;
    const EUnauthorized: u64 = 3;
    const EAlreadyReleased: u64 = 4;
    const EAlreadyRefunded: u64 = 5;
    const EDeadlineNotReached: u64 = 6;

    // ==================== Structs ====================

    /// Escrow holding payment for a shipment
    public struct PaymentEscrow has key, store {
        id: UID,
        /// Shipment this escrow is for
        shipment_id: String,
        /// Amount held in escrow
        amount: u64,
        /// Actual coins held
        balance: Coin<SUI>,
        /// Customer who made the payment
        customer: address,
        /// Logistics provider who will receive payment
        provider: address,
        /// Deadline for delivery (Unix ms), refund allowed after this
        deadline: u64,
        /// Whether payment has been released
        released: bool,
        /// Whether payment has been refunded
        refunded: bool,
        /// Creation timestamp
        created_at: u64,
    }

    /// Capability to release escrow (held by logistics provider)
    public struct EscrowReleaseCap has key, store {
        id: UID,
        escrow_id: ID,
    }

    // ==================== Events ====================

    /// Event when escrow is created
    public struct EscrowCreated has copy, drop {
        escrow_id: ID,
        shipment_id: String,
        amount: u64,
        customer: address,
        provider: address,
        deadline: u64,
    }

    /// Event when escrow is released to provider
    public struct EscrowReleased has copy, drop {
        escrow_id: ID,
        shipment_id: String,
        amount: u64,
        recipient: address,
    }

    /// Event when escrow is refunded to customer
    public struct EscrowRefunded has copy, drop {
        escrow_id: ID,
        shipment_id: String,
        amount: u64,
        recipient: address,
    }

    // ==================== Public Functions ====================

    /// Create a new payment escrow for COD shipment
    public fun create_escrow(
        payment: Coin<SUI>,
        shipment_id: String,
        provider: address,
        deadline: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (PaymentEscrow, EscrowReleaseCap) {
        let amount = coin::value(&payment);
        let customer = tx_context::sender(ctx);

        let escrow = PaymentEscrow {
            id: object::new(ctx),
            shipment_id,
            amount,
            balance: payment,
            customer,
            provider,
            deadline,
            released: false,
            refunded: false,
            created_at: clock::timestamp_ms(clock),
        };

        let release_cap = EscrowReleaseCap {
            id: object::new(ctx),
            escrow_id: object::id(&escrow),
        };

        event::emit(EscrowCreated {
            escrow_id: object::id(&escrow),
            shipment_id: escrow.shipment_id,
            amount,
            customer,
            provider,
            deadline,
        });

        (escrow, release_cap)
    }

    /// Release escrow to provider after delivery confirmation
    /// Only the release cap holder can call this
    public fun release_payment(
        escrow: &mut PaymentEscrow,
        cap: EscrowReleaseCap,
        ctx: &mut TxContext
    ) {
        assert!(!escrow.released, EAlreadyReleased);
        assert!(!escrow.refunded, EAlreadyRefunded);
        assert!(cap.escrow_id == object::id(escrow), EUnauthorized);

        escrow.released = true;

        // Transfer funds to provider
        let balance = coin::split(&mut escrow.balance, escrow.amount, ctx);
        transfer::public_transfer(balance, escrow.provider);

        event::emit(EscrowReleased {
            escrow_id: object::id(escrow),
            shipment_id: escrow.shipment_id,
            amount: escrow.amount,
            recipient: escrow.provider,
        });

        // Destroy the release cap
        let EscrowReleaseCap { id, escrow_id: _ } = cap;
        object::delete(id);
    }

    /// Refund escrow to customer if deadline passed
    /// Only the customer can call this after deadline
    public fun refund_payment(
        escrow: &mut PaymentEscrow,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!escrow.released, EAlreadyReleased);
        assert!(!escrow.refunded, EAlreadyRefunded);
        assert!(tx_context::sender(ctx) == escrow.customer, EUnauthorized);
        assert!(clock::timestamp_ms(clock) > escrow.deadline, EDeadlineNotReached);

        escrow.refunded = true;

        // Return funds to customer
        let balance = coin::split(&mut escrow.balance, escrow.amount, ctx);
        transfer::public_transfer(balance, escrow.customer);

        event::emit(EscrowRefunded {
            escrow_id: object::id(escrow),
            shipment_id: escrow.shipment_id,
            amount: escrow.amount,
            recipient: escrow.customer,
        });
    }

    /// Share the escrow so it can be accessed
    public fun share_escrow(escrow: PaymentEscrow) {
        transfer::share_object(escrow);
    }

    /// Transfer release capability to provider
    public fun transfer_release_cap(cap: EscrowReleaseCap, recipient: address) {
        transfer::transfer(cap, recipient);
    }

    // ==================== View Functions ====================

    /// Get escrow amount
    public fun get_amount(escrow: &PaymentEscrow): u64 {
        escrow.amount
    }

    /// Get shipment ID
    public fun get_shipment_id(escrow: &PaymentEscrow): String {
        escrow.shipment_id
    }

    /// Check if released
    public fun is_released(escrow: &PaymentEscrow): bool {
        escrow.released
    }

    /// Check if refunded
    public fun is_refunded(escrow: &PaymentEscrow): bool {
        escrow.refunded
    }

    /// Get deadline
    public fun get_deadline(escrow: &PaymentEscrow): u64 {
        escrow.deadline
    }

    /// Get customer address
    public fun get_customer(escrow: &PaymentEscrow): address {
        escrow.customer
    }

    /// Get provider address
    public fun get_provider(escrow: &PaymentEscrow): address {
        escrow.provider
    }
}

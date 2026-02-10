/// Proof of Delivery Smart Contract for Logistics Platform
/// Stores immutable delivery proofs on Sui blockchain
module logistics::delivery_proof {
    use std::string::{Self, String};
    use sui::event;
    use sui::clock::{Self, Clock};

    // ==================== Error Codes ====================
    const EInvalidShipmentId: u64 = 1;
    const EProofAlreadyExists: u64 = 2;
    const EUnauthorized: u64 = 3;

    // ==================== Structs ====================

    /// Registry to track all delivery proofs
    public struct DeliveryRegistry has key {
        id: UID,
        total_proofs: u64,
        organization_id: String,
    }

    /// Proof of Delivery NFT - immutable record of delivery
    public struct DeliveryProof has key, store {
        id: UID,
        /// Unique shipment identifier from logistics system
        shipment_id: String,
        /// Tracking number for reference
        tracking_number: String,
        /// Delivery timestamp (Unix ms)
        delivered_at: u64,
        /// Digital signature from recipient (base64 encoded)
        recipient_signature: vector<u8>,
        /// Photo hash (IPFS CID or SHA256)
        photo_hash: String,
        /// Recipient name
        recipient_name: String,
        /// GPS coordinates at delivery
        gps_lat: u64,  // Multiplied by 1e6 for precision
        gps_lng: u64,  // Multiplied by 1e6 for precision
        /// Driver who made the delivery
        driver_id: String,
        driver_name: String,
        /// Vehicle used
        vehicle_id: String,
        plate_number: String,
        /// Notes or comments
        notes: String,
        /// Block timestamp when proof was created
        created_at: u64,
    }

    /// Admin capability for managing the registry
    public struct AdminCap has key, store {
        id: UID,
    }

    // ==================== Events ====================

    /// Event emitted when delivery is confirmed
    public struct DeliveryConfirmed has copy, drop {
        proof_id: ID,
        shipment_id: String,
        tracking_number: String,
        delivered_at: u64,
        driver_id: String,
        recipient_name: String,
    }

    /// Event emitted when registry is created
    public struct RegistryCreated has copy, drop {
        registry_id: ID,
        organization_id: String,
    }

    // ==================== Init ====================

    /// Initialize the module and create admin capability
    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    // ==================== Public Functions ====================

    /// Create a new delivery registry for an organization
    public fun create_registry(
        _admin: &AdminCap,
        organization_id: String,
        ctx: &mut TxContext
    ): DeliveryRegistry {
        let registry = DeliveryRegistry {
            id: object::new(ctx),
            total_proofs: 0,
            organization_id,
        };

        event::emit(RegistryCreated {
            registry_id: object::id(&registry),
            organization_id: registry.organization_id,
        });

        registry
    }

    /// Confirm delivery and create immutable proof
    public fun confirm_delivery(
        registry: &mut DeliveryRegistry,
        clock: &Clock,
        shipment_id: String,
        tracking_number: String,
        recipient_signature: vector<u8>,
        photo_hash: String,
        recipient_name: String,
        gps_lat: u64,
        gps_lng: u64,
        driver_id: String,
        driver_name: String,
        vehicle_id: String,
        plate_number: String,
        notes: String,
        ctx: &mut TxContext
    ): DeliveryProof {
        // Validate shipment_id is not empty
        assert!(string::length(&shipment_id) > 0, EInvalidShipmentId);

        let current_time = clock::timestamp_ms(clock);
        
        let proof = DeliveryProof {
            id: object::new(ctx),
            shipment_id,
            tracking_number,
            delivered_at: current_time,
            recipient_signature,
            photo_hash,
            recipient_name,
            gps_lat,
            gps_lng,
            driver_id,
            driver_name,
            vehicle_id,
            plate_number,
            notes,
            created_at: current_time,
        };

        // Update registry counter
        registry.total_proofs = registry.total_proofs + 1;

        // Emit event
        event::emit(DeliveryConfirmed {
            proof_id: object::id(&proof),
            shipment_id: proof.shipment_id,
            tracking_number: proof.tracking_number,
            delivered_at: proof.delivered_at,
            driver_id: proof.driver_id,
            recipient_name: proof.recipient_name,
        });

        proof
    }

    /// Share the registry so anyone can read it
    public fun share_registry(registry: DeliveryRegistry) {
        transfer::share_object(registry);
    }

    /// Transfer proof to recipient (customer)
    public fun transfer_proof(proof: DeliveryProof, recipient: address) {
        transfer::transfer(proof, recipient);
    }

    // ==================== View Functions ====================

    /// Get shipment ID from proof
    public fun get_shipment_id(proof: &DeliveryProof): String {
        proof.shipment_id
    }

    /// Get tracking number from proof
    public fun get_tracking_number(proof: &DeliveryProof): String {
        proof.tracking_number
    }

    /// Get delivery timestamp
    public fun get_delivered_at(proof: &DeliveryProof): u64 {
        proof.delivered_at
    }

    /// Get recipient name
    public fun get_recipient_name(proof: &DeliveryProof): String {
        proof.recipient_name
    }

    /// Get GPS coordinates
    public fun get_gps_coordinates(proof: &DeliveryProof): (u64, u64) {
        (proof.gps_lat, proof.gps_lng)
    }

    /// Get driver info
    public fun get_driver_info(proof: &DeliveryProof): (String, String) {
        (proof.driver_id, proof.driver_name)
    }

    /// Get total proofs in registry
    public fun get_total_proofs(registry: &DeliveryRegistry): u64 {
        registry.total_proofs
    }

    /// Get organization ID from registry
    public fun get_organization_id(registry: &DeliveryRegistry): String {
        registry.organization_id
    }

    // ==================== Test Functions ====================

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}

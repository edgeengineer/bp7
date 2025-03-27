import Testing
@testable import BP7

@Suite("Administrative Record Tests")
struct AdministrativeRecordTests {
    @Test("Bundle Status Item")
    func testBundleStatusItem() {
        // Test creating a bundle status item
        let item1 = BundleStatusItem(asserted: true)
        #expect(item1.asserted)
        #expect(!item1.statusRequested)
        #expect(item1.time == 0)
        
        let item2 = BundleStatusItem(asserted: true, statusRequested: true)
        #expect(item2.asserted)
        #expect(item2.statusRequested)
        #expect(item2.time == 0)
        
        let time = DisruptionTolerantNetworkingTime.now()
        let item3 = BundleStatusItem(timeReporting: time)
        #expect(item3.asserted)
        #expect(item3.statusRequested)
        #expect(item3.time == time)
        
        // Test equality
        #expect(item1 == BundleStatusItem(asserted: true))
        #expect(item1 != item2)
        #expect(item2 != item3)
    }
    
    @Test("Status Report")
    func testStatusReport() {
        // Create test data
        let sourceNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/"))
        let timestamp = CreationTimestamp(time: 1000, sequenceNumber: 1)
        let statusItems = [
            BundleStatusItem(asserted: true),
            BundleStatusItem(asserted: false),
            BundleStatusItem(asserted: true, statusRequested: true),
            BundleStatusItem(asserted: false, statusRequested: true)
        ]
        
        // Create status report
        let report = StatusReport(
            statusInformation: statusItems,
            reportReason: StatusReportReason.noInformation,
            sourceNode: sourceNode,
            timestamp: timestamp
        )
        
        // Test properties
        #expect(report.statusInformation.count == 4)
        #expect(report.statusInformation[0].asserted)
        #expect(!report.statusInformation[0].statusRequested)
        #expect(!report.statusInformation[1].asserted)
        #expect(!report.statusInformation[1].statusRequested)
        #expect(report.statusInformation[2].asserted)
        #expect(report.statusInformation[2].statusRequested)
        #expect(!report.statusInformation[3].asserted)
        #expect(report.statusInformation[3].statusRequested)
        #expect(report.reportReason == .noInformation)
        #expect(report.sourceNode == sourceNode)
        #expect(report.timestamp == timestamp)
        
        // Test CBOR encoding
        do {
            let cbor = try report.encode()
            // Check that CBOR encoding was successful
            #expect(Bool(true))
            
            // Test decoding
            do {
                let decoded = try StatusReport.decode(from: cbor)
                #expect(decoded.statusInformation.count == 4)
                #expect(decoded.statusInformation[0].asserted == report.statusInformation[0].asserted)
                #expect(decoded.statusInformation[1].asserted == report.statusInformation[1].asserted)
                #expect(decoded.statusInformation[2].asserted == report.statusInformation[2].asserted)
                #expect(decoded.statusInformation[3].asserted == report.statusInformation[3].asserted)
                #expect(decoded.reportReason == report.reportReason)
                #expect(decoded.sourceNode == report.sourceNode)
                #expect(decoded.timestamp == report.timestamp)
            } catch {
                #expect(Bool(false), "Decoding should not throw: \(error)")
            }
        } catch {
            #expect(Bool(false), "Encoding should not throw: \(error)")
        }
    }
    
    @Test("Administrative Record")
    func testAdministrativeRecord() {
        // Create test data
        let sourceNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/"))
        let timestamp = CreationTimestamp(time: 1000, sequenceNumber: 1)
        let statusItems = [
            BundleStatusItem(asserted: true),
            BundleStatusItem(asserted: false),
            BundleStatusItem(asserted: true, statusRequested: true),
            BundleStatusItem(asserted: false, statusRequested: true)
        ]
        
        // Create status report
        let report = StatusReport(
            statusInformation: statusItems,
            reportReason: StatusReportReason.noInformation,
            sourceNode: sourceNode,
            timestamp: timestamp
        )
        
        // Create administrative record
        let record = AdministrativeRecord.bundleStatusReport(report)
        
        // Test properties
        if case .bundleStatusReport(let statusReport) = record {
            #expect(statusReport.statusInformation.count == 4)
            #expect(statusReport.reportReason == StatusReportReason.noInformation)
            #expect(statusReport.sourceNode == sourceNode)
            #expect(statusReport.timestamp == timestamp)
        } else {
            #expect(Bool(false), "Expected status report")
        }
        
        // Test CBOR encoding
        do {
            let cbor = try record.encode()
            // Check that CBOR encoding was successful
            #expect(Bool(true))
            
            // Test decoding
            do {
                let decoded = try AdministrativeRecord.decode(from: cbor)
                if case .bundleStatusReport(let statusReport) = decoded {
                    #expect(statusReport.statusInformation.count == 4)
                    #expect(statusReport.reportReason == report.reportReason)
                    #expect(statusReport.sourceNode == report.sourceNode)
                    #expect(statusReport.timestamp == report.timestamp)
                } else {
                    #expect(Bool(false), "Expected status report")
                }
            } catch {
                #expect(Bool(false), "Decoding should not throw: \(error)")
            }
        } catch {
            #expect(Bool(false), "Encoding should not throw: \(error)")
        }
        
        // Test to canonical block
        let block = record.toPayload()
        #expect(block.blockType == BlockType.payload.rawValue)
        #expect(block.blockNumber == 1)
        #expect(block.payloadData() != nil)
    }
    
    @Test("New Status Report")
    func testNewStatusReport() {
        // Create a bundle
        let primaryBlock = PrimaryBlock(
            version: 7,
            bundleControlFlags: [.bundleRequestStatusTime],
            crc: .crcNo,
            destination: EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600
        )
        
        let bundle = Bundle(
            primary: primaryBlock,
            canonicals: [try! CanonicalBlock(blockControlFlags: BlockControlFlags(), payloadData: [1, 2, 3, 4, 5])]
        )
        
        // Create status report
        let report = StatusReport(
            bundle: bundle,
            statusItem: StatusInformationPos.receivedBundle,
            reason: .noInformation
        )
        
        // Test properties
        #expect(report.statusInformation.count == 4)
        #expect(report.statusInformation[Int(StatusInformationPos.receivedBundle.rawValue)].asserted)
        #expect(report.statusInformation[Int(StatusInformationPos.receivedBundle.rawValue)].statusRequested)
        #expect(!report.statusInformation[Int(StatusInformationPos.forwardedBundle.rawValue)].asserted)
        #expect(!report.statusInformation[Int(StatusInformationPos.deliveredBundle.rawValue)].asserted)
        #expect(!report.statusInformation[Int(StatusInformationPos.deletedBundle.rawValue)].asserted)
        #expect(report.reportReason == .noInformation)
        #expect(report.sourceNode == bundle.primary.source)
        #expect(report.timestamp == bundle.primary.creationTimestamp)
    }
    
    @Test("New Status Report Bundle")
    func testNewStatusReportBundle() {
        // Create a bundle
        let primaryBlock = PrimaryBlock(
            version: 7,
            bundleControlFlags: [.bundleRequestStatusTime],
            crc: .crcNo,
            destination: EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/")),
            source: EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/")),
            reportTo: EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600
        )
        
        let bundle = Bundle(
            primary: primaryBlock,
            canonicals: [try! CanonicalBlock(blockControlFlags: BlockControlFlags(), payloadData: [1, 2, 3, 4, 5])]
        )
        
        // Create status report bundle
        let sourceNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//reporting-node/"))
        let reportBundle = StatusReport.newBundle(
            origBundle: bundle,
            source: sourceNode,
            crcType: .crcNo,
            status: .receivedBundle,
            reason: .noInformation
        )
        
        // Test payload
        #expect(reportBundle.canonicals.count == 1)
        #expect(reportBundle.canonicals[0].blockType == BlockType.payload.rawValue)
        #expect(reportBundle.canonicals[0].blockNumber == 1)
        
        // Test primary block
        #expect(reportBundle.primary.version == 7)
        #expect(reportBundle.primary.bundleControlFlags.contains(.bundleAdministrativeRecordPayload))
        #expect(reportBundle.primary.destination == bundle.primary.reportTo)
        #expect(reportBundle.primary.source == sourceNode)
        #expect(reportBundle.primary.reportTo == sourceNode)
    }
}

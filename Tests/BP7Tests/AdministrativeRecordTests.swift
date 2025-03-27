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
        
        // Test creating a time reporting bundle status item
        let time: DisruptionTolerantNetworkingTime = 12345
        let item2 = BundleStatusItem(timeReporting: time)
        #expect(item2.asserted)
        #expect(item2.statusRequested)
        #expect(item2.time == time)
        
        // Test CBOR encoding and decoding
        let cbor1 = item1.encode()
        let cbor2 = item2.encode()
        
        do {
            let decoded1 = try BundleStatusItem.decode(from: cbor1)
            #expect(decoded1.asserted == item1.asserted)
            #expect(decoded1.statusRequested == item1.statusRequested)
            #expect(decoded1.time == item1.time)
            
            let decoded2 = try BundleStatusItem.decode(from: cbor2)
            #expect(decoded2.asserted == item2.asserted)
            #expect(decoded2.statusRequested == item2.statusRequested)
            #expect(decoded2.time == item2.time)
        } catch {
            #expect(Bool(false), "Decoding bundle status item failed: \(error)")
        }
    }
    
    @Test("Status Report")
    func testStatusReport() {
        // Create test data
        let sourceNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/"))
        let timestamp = CreationTimestamp(time: 1000, sequenceNumber: 1)
        let statusItems = [
            BundleStatusItem(asserted: true),
            BundleStatusItem(asserted: false),
            BundleStatusItem(timeReporting: 12345),
            BundleStatusItem(asserted: false)
        ]
        
        // Create status report
        let statusReport = StatusReport(
            statusInformation: statusItems,
            reportReason: .noInformation,
            sourceNode: sourceNode,
            timestamp: timestamp
        )
        
        // Test properties
        #expect(statusReport.statusInformation.count == 4)
        #expect(statusReport.reportReason == .noInformation)
        #expect(statusReport.sourceNode == sourceNode)
        #expect(statusReport.timestamp.getDtnTime() == timestamp.getDtnTime())
        #expect(statusReport.timestamp.getSequenceNumber() == timestamp.getSequenceNumber())
        #expect(statusReport.fragOffset == 0)
        #expect(statusReport.fragLen == 0)
        
        // Test reference string
        let refString = statusReport.refBundle()
        #expect(refString == "\(sourceNode)-\(timestamp.getDtnTime())-\(timestamp.getSequenceNumber())")
        
        // Test CBOR encoding and decoding
        do {
            let cbor = try statusReport.encode()
            let decoded = try StatusReport.decode(from: cbor)
            
            // Test decoded properties
            #expect(decoded.statusInformation.count == statusReport.statusInformation.count)
            #expect(decoded.reportReason == statusReport.reportReason)
            #expect(decoded.sourceNode == statusReport.sourceNode)
            #expect(decoded.timestamp.getDtnTime() == statusReport.timestamp.getDtnTime())
            #expect(decoded.timestamp.getSequenceNumber() == statusReport.timestamp.getSequenceNumber())
            #expect(decoded.fragOffset == statusReport.fragOffset)
            #expect(decoded.fragLen == statusReport.fragLen)
        } catch {
            #expect(Bool(false), "Encoding/decoding status report failed: \(error)")
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
            BundleStatusItem(timeReporting: 12345),
            BundleStatusItem(asserted: false)
        ]
        
        // Create status report
        let statusReport = StatusReport(
            statusInformation: statusItems,
            reportReason: .noInformation,
            sourceNode: sourceNode,
            timestamp: timestamp
        )
        
        // Create administrative record
        let adminRecord = AdministrativeRecord.bundleStatusReport(statusReport)
        
        // Test CBOR encoding and decoding
        do {
            let cbor = try adminRecord.encode()
            let decoded = try AdministrativeRecord.decode(from: cbor)
            
            // Test decoded properties
            if case .bundleStatusReport(let decodedReport) = decoded {
                #expect(decodedReport.statusInformation.count == statusReport.statusInformation.count)
                #expect(decodedReport.reportReason == statusReport.reportReason)
                #expect(decodedReport.sourceNode == statusReport.sourceNode)
                #expect(decodedReport.timestamp.getDtnTime() == statusReport.timestamp.getDtnTime())
                #expect(decodedReport.timestamp.getSequenceNumber() == statusReport.timestamp.getSequenceNumber())
            } else {
                #expect(Bool(false), "Decoded administrative record is not a bundle status report")
            }
        } catch {
            #expect(Bool(false), "Encoding/decoding administrative record failed: \(error)")
        }
    }
    
    @Test("Status Report Bundle")
    func testStatusReportBundle() {
        // Create test data
        let sourceNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//source/"))
        let reportTo = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/"))
        let destination = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//destination/"))
        
        // Create a primary block for the original bundle
        let primaryBlock = try! PrimaryBlockBuilder()
            .destination(destination)
            .source(sourceNode)
            .reportTo(reportTo)
            .creationTimestamp(CreationTimestamp(time: 1000, sequenceNumber: 1))
            .lifetime(3600)
            .bundleControlFlags([.bundleMustNotFragmented])
            .build()
        
        // Create the original bundle
        let bundle = Bundle(primary: primaryBlock)
        
        // Create a status report bundle
        let reportBundle = StatusReport.newBundle(
            origBundle: bundle,
            source: sourceNode,
            crcType: CrcValue.crcNo,
            status: .receivedBundle,
            reason: .noInformation
        )
        
        // Test bundle properties
        #expect(reportBundle.primary.destination == bundle.primary.reportTo)
        #expect(reportBundle.primary.source == sourceNode)
        #expect(reportBundle.primary.reportTo == sourceNode)
        #expect(reportBundle.primary.bundleControlFlags.contains(.bundleAdministrativeRecordPayload))
        #expect(reportBundle.primary.lifetime == bundle.primary.lifetime)
        
        // Test payload
        #expect(reportBundle.canonicals.count == 1)
        #expect(reportBundle.canonicals[0].blockType == PAYLOAD_BLOCK)
        #expect(reportBundle.canonicals[0].payloadData() != nil)
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
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600
        )
        
        let bundle = Bundle(
            primary: primaryBlock,
            canonicals: [try! CanonicalBlock.newPayloadBlock(blockControlFlags: [], data: [1, 2, 3, 4, 5])]
        )
        
        // Create status report
        let report = StatusReport(
            bundle: bundle,
            statusItem: StatusInformationPos.receivedBundle,
            reason: StatusReportReason.noInformation
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
            reportTo: try! EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//report-to/")),
            creationTimestamp: CreationTimestamp(time: 1000, sequenceNumber: 1),
            lifetime: 3600
        )
        
        let bundle = Bundle(
            primary: primaryBlock,
            canonicals: [try! CanonicalBlock.newPayloadBlock(blockControlFlags: [], data: [1, 2, 3, 4, 5])]
        )
        
        // Create status report bundle
        let sourceNode = EndpointID.dtn(EndpointScheme.DTN, DTNAddress("//reporting-node/"))
        let reportBundle = StatusReport.newBundle(
            origBundle: bundle,
            source: sourceNode,
            crcType: CrcValue.crcNo,
            status: .receivedBundle,
            reason: .noInformation
        )
        
        // Test bundle properties
        #expect(reportBundle.primary.destination == bundle.primary.reportTo)
        #expect(reportBundle.primary.source == sourceNode)
        #expect(reportBundle.primary.reportTo == sourceNode)
        #expect(reportBundle.primary.bundleControlFlags.contains(.bundleAdministrativeRecordPayload))
        #expect(reportBundle.primary.lifetime == bundle.primary.lifetime)
        
        // Test payload
        #expect(reportBundle.canonicals.count == 1)
        #expect(reportBundle.canonicals[0].blockType == PAYLOAD_BLOCK)
        #expect(reportBundle.canonicals[0].payloadData() != nil)
    }
}

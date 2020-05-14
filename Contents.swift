import Cocoa

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}



let fileURL = Bundle.main.url(forResource: "testRGB50", withExtension: "acv")

let testData = try Data(contentsOf: fileURL!)

func openCurve(url: URL) -> PhotoshopCurve? {
    let psCurve = PhotoshopCurve(acvFile: url)
    return psCurve
}


class PhotoshopCurve {
    
    var loadedCurve : Data?
    var exportCurve : Data?
    
    var acvData = [UInt8]()
    
    init(acvFile: URL){
        do {
            loadedCurve = try Data(contentsOf: acvFile)
            
            print("Loaded ACV File")
            if validateACVFile() {
            print("Initial Curve Values")
            parseACV()
            segmentCurveChannels()
            print("OutputCurve ACV")
            writeACV()
            saveACVCurve(acvData: acvData)
            } else {
                print("not a valid acv file")
            }
        } catch {
            print("not a valid acv file")
        }
    }
    
    // defualt number of curve channels
    var nChannels = UInt8(1)
    
    var nGrayCurvePoints = UInt8(2)
    
    // placeholder array of tupels for input/output curve points
    var compCurvePoints : [(UInt8,UInt8)] = [(0, 0),(255, 255)]
    var rCurvePoints : [(UInt8,UInt8)] = [(0, 0),(255, 255)]
    var gCurvePoints : [(UInt8,UInt8)] = [(0, 0),(255, 255)]
    var bCurvePoints : [(UInt8,UInt8)] = [(0, 0),(255, 255)]
    
    var kCurvePoints : [(UInt8,UInt8)] = [(0, 0),(255, 255)]
    
    func validateACVFile() -> Bool {
        guard let testData = loadedCurve else {
            return false
        }
        if testData[0] == UInt8(0) && testData[1] == 4 {
            return true
        }
        else {
            return false
        }
    }
    
    func getNumCurveChannels() -> UInt8 {
        guard let curve = loadedCurve else { return 0 }
        return curve[3]
    }
    
    func parseACV(){
        guard let curve = loadedCurve else { return }
        let size = curve.count
        
        var tempData = [UInt8]()
        var i = 1
        for _ in 0..<size/2 {
            tempData.append(curve[i])
            i += 2
        }
        acvData = tempData
        print(acvData)
    }
    
    func getNCurvePoints(startingIndex: Int) -> Int {
       return Int(acvData[startingIndex])
    }
    
    func incremementStartingIndex(preStartingIndex: Int, nPrevPoints: Int) -> Int {
        return nPrevPoints * 2 + preStartingIndex + 1
    }
    
    func getCurvePoints(nPoints: Int, startingIndex: Int) -> [(UInt8,UInt8)] {
       var tempCurvePoints : [(UInt8,UInt8)] = []
        var i = 1
        for _ in 0..<nPoints {
            let p0 = acvData[startingIndex + i]
            let p1 = acvData[startingIndex + i + 1]
            tempCurvePoints.append((p0,p1))
            i += 2
        }
        return tempCurvePoints
    }
    
    func segmentRGBCurve() {
        var startingIndex = 2
        var nPoints = getNCurvePoints(startingIndex: startingIndex)
        compCurvePoints = getCurvePoints(nPoints: nPoints, startingIndex: startingIndex)
        
        startingIndex = incremementStartingIndex(preStartingIndex: startingIndex, nPrevPoints: nPoints)
        nPoints = getNCurvePoints(startingIndex: startingIndex)
        rCurvePoints = getCurvePoints(nPoints: nPoints, startingIndex: startingIndex)
        
        startingIndex = incremementStartingIndex(preStartingIndex: startingIndex, nPrevPoints: nPoints)
        nPoints = getNCurvePoints(startingIndex: startingIndex)
        gCurvePoints = getCurvePoints(nPoints: nPoints, startingIndex: startingIndex)
        
        startingIndex = incremementStartingIndex(preStartingIndex: startingIndex, nPrevPoints: nPoints)
        nPoints = getNCurvePoints(startingIndex: startingIndex)
        bCurvePoints = getCurvePoints(nPoints: nPoints, startingIndex: startingIndex)
 
    }
    
    func segmentCurveChannels() {
        nChannels = getNumCurveChannels()
        switch nChannels {
        case 2 :
            print("Grayscale Curve")
        case 5:
            segmentRGBCurve()
        case 6:
            print("CMYK Curve")
        default:
            print("unknown curve type")
        }
        
    }
    
    func saveACVCurve(acvData: [UInt8]) {
        let data = Data(acvData)
        let url = getDocumentsDirectory().appendingPathComponent("testPSCurve.acv")
        do {
            try data.write(to: url)
        } catch {
            print(error.localizedDescription)
        }
        
    }
    
    func writeACV() {
        var curveArray = writeACVHeader()
        switch nChannels {
        case 2 :
            print("Grayscale Curve")
        case 5:
            print("RGB Curve")
            curveArray.append(contentsOf: writeRGBCurve())
            print(curveArray)
        case 6:
            print("CMYK Curve")
        default:
            print("unknown curve type")
        }
        print(curveArray.count)
        
    }
    
    private func writeRGBCurve() -> [UInt8] {
        var tempValues = [UInt8]()
        tempValues.append(contentsOf: writeCurveData(curveValues: compCurvePoints))
        tempValues.append(contentsOf: writeCurveData(curveValues: rCurvePoints))
        tempValues.append(contentsOf: writeCurveData(curveValues: gCurvePoints))
        tempValues.append(contentsOf: writeCurveData(curveValues: bCurvePoints))
        tempValues.append(contentsOf: writeLastACVData())
        return tempValues
    }
    
    private func writeACVHeader() -> [UInt8] {
        var tempValues = [UInt8]()
        //start with null character for padding
        tempValues.append(0)
        // write ACV version 4
        tempValues.append(4)
        // write count of curve channels : 5 for RGBA or 2 for grayscale
        tempValues.append(0)
        tempValues.append(nChannels)
        
        return tempValues
    }
    
    private func writeCurveData(curveValues: [(UInt8,UInt8)]) -> [UInt8] {
        var tempValues = [UInt8]()
        tempValues.append(0)
        tempValues.append(UInt8(curveValues.count))
        for p in curveValues {
            tempValues.append(0)
            tempValues.append(p.0)
            tempValues.append(0)
            tempValues.append(p.1)
        }
        return tempValues
    }
    
    private func writeLastACVData() -> [UInt8]{
       var tempValues = [UInt8]()
        tempValues.append(0) //padding
        tempValues.append(2)
        
        tempValues.append(0) //padding
        tempValues.append(0)
        //padding
        tempValues.append(0) //padding
        tempValues.append(0)
        //padding
        tempValues.append(0) //padding
        tempValues.append(255)
        //padding
        tempValues.append(0) //padding
        tempValues.append(255)
        return(tempValues)
    }

}



let acv = openCurve(url: fileURL!)

import Testing
@testable import PipingDatabase

struct TradeCalcTests {
    @Test func feetInchFractionEntry() {
        var e = TradeCalcEngine()
        e.digit(5); e.feet(); e.digit(3); e.fraction(sixteenths: 8) // 5'-3 1/2"
        #expect(e.displayInches == 63.5)
        #expect(e.displayText == "5'-3 1/2\"")
    }

    @Test func additionAcrossFeetAndFractions() {
        var e = TradeCalcEngine()
        e.digit(1); e.feet(); e.digit(6)          // 1'-6"
        e.op(.add)
        e.digit(2); e.fraction(sixteenths: 4)     // 2 1/4"
        e.equals()
        #expect(e.displayInches == 20.25)
        #expect(e.displayText == "1'-8 1/4\"")
    }

    @Test func subtractionAndNegative() {
        var e = TradeCalcEngine()
        e.digit(6)
        e.op(.sub)
        e.digit(1); e.feet()
        e.equals()
        #expect(e.displayInches == -6)
        #expect(e.displayText == "-0'-6\"")
    }

    @Test func multiplicationAndDivision() {
        var e = TradeCalcEngine()
        e.digit(8)
        e.op(.mul)
        e.digit(3)
        e.equals()
        #expect(e.displayInches == 24)

        e.op(.div)
        e.digit(4)
        e.equals()
        #expect(e.displayInches == 6)
    }

    @Test func divisionByZeroIsSafe() {
        var e = TradeCalcEngine()
        e.digit(9)
        e.op(.div)
        e.digit(0)
        e.equals()
        #expect(e.displayInches == 0)
    }

    @Test func memory() {
        var e = TradeCalcEngine()
        e.digit(1); e.digit(2)
        e.memoryAdd()
        e.allClear()
        #expect(e.memory == 12)
        e.digit(2)
        e.memorySubtract()
        #expect(e.memory == 10)
        e.memoryRecall()
        #expect(e.displayInches == 10)
        e.memoryClear()
        #expect(e.memory == 0)
    }

    @Test func modesFormat() {
        #expect(TradeCalcEngine.format(inches: 63.5, mode: .feetInches) == "5'-3 1/2\"")
        #expect(TradeCalcEngine.format(inches: 63.5, mode: .decimalInches) == "63.500\"")
        #expect(TradeCalcEngine.format(inches: 1.0, mode: .millimeters) == "25.4 mm")
        #expect(TradeCalcEngine.format(inches: 0, mode: .feetInches) == "0'-0\"")
        #expect(TradeCalcEngine.format(inches: 11.9999, mode: .feetInches) == "1'-0\"")
    }

    @Test func backspaceEditsEntry() {
        var e = TradeCalcEngine()
        e.digit(1); e.digit(2); e.fraction(sixteenths: 8)
        e.backspace()                 // clears fraction first
        #expect(e.displayInches == 12)
        e.backspace()                 // then last digit
        #expect(e.displayInches == 1)
    }

    @Test func chainedOperations() {
        var e = TradeCalcEngine()
        e.digit(2)
        e.op(.add)
        e.digit(3)
        e.op(.add)                    // commits 2+3 on the way
        e.digit(4)
        e.equals()
        #expect(e.displayInches == 9)
    }
}

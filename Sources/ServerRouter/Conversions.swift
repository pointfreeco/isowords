import Parsing

struct Conversion<Input, Output>: ParserPrinter {
  let apply: (Input) -> Output
  let unapply: (Output) -> Input
  
  func parse(_ input: inout Input) -> Output? {
    self.apply(input)
  }
  
  func print(_ output: Output) -> Input? {
    self.unapply(output)
  }
}

struct PartialConversion<Input, Output>: ParserPrinter {
  let apply: (Input) -> Output?
  let unapply: (Output) -> Input?
  
  func parse(_ input: inout Input) -> Output? {
    self.apply(input)
  }
  
  func print(_ output: Output) -> Input? {
    self.unapply(output)
  }
}

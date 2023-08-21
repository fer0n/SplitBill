//
//  NSExpression.swift
//  SplitBill
//
//  Created by fer0n on 21.08.23.
//

import Foundation

//https://stackoverflow.com/questions/46550658/can-i-force-nsexpression-and-expressionvalue-to-assume-doubles-instead-of-ints-s
extension NSExpression {
    
    /**
     Converts an expression to floating point values if it includes a divition. Otherwise an integer division is used, resulting in a wrong result.
     */
    func toFloatingPointDivision() -> NSExpression {
        switch expressionType {
        case .function where function == "divide:by:":
            guard let args = arguments else { break }
            let newArgs = args.map({ arg -> NSExpression in
                if arg.expressionType == .constantValue {
                    if let value = arg.constantValue as? Double {
                        return NSExpression(forConstantValue: value)
                    } else {
                        return arg
                    }
                } else {
                    return NSExpression(block: { (object, arguments, context) in
                        // NB: The type of `+[NSExpression expressionForBlock:arguments]` is incorrect.
                        // It claims the arguments is an array of NSExpressions, but it's not, it's
                        // actually an array of the evaluated values. We can work around this by going
                        // through NSArray.
                        guard let arg = (arguments as NSArray).firstObject else { return NSNull() }
                        return (arg as? Double) ?? arg
                    }, arguments: [arg.toFloatingPointDivision()])
                }
            })
            return NSExpression(forFunction: operand, selectorName: function, arguments: newArgs)
        case .function:
            guard let args = arguments else { break }
            let newArgs = args.map({ $0.toFloatingPointDivision() })
            return NSExpression(forFunction: operand, selectorName: function, arguments: newArgs)
        case .conditional:
            return NSExpression(forConditional: predicate,
                                trueExpression: self.true.toFloatingPointDivision(),
                                falseExpression: self.false.toFloatingPointDivision())
        case .unionSet:
            return NSExpression(forUnionSet: left.toFloatingPointDivision(), with: right.toFloatingPointDivision())
        case .intersectSet:
            return NSExpression(forIntersectSet: left.toFloatingPointDivision(), with: right.toFloatingPointDivision())
        case .minusSet:
            return NSExpression(forMinusSet: left.toFloatingPointDivision(), with: right.toFloatingPointDivision())
        case .subquery:
            if let subQuery = collection as? NSExpression {
                return NSExpression(forSubquery: subQuery.toFloatingPointDivision(), usingIteratorVariable: variable, predicate: predicate)
            }
        case .aggregate:
            if let subExpressions = collection as? [NSExpression] {
                return NSExpression(forAggregate: subExpressions.map({ $0.toFloatingPointDivision() }))
            }
        case .block:
            guard let args = arguments else { break }
            let newArgs = args.map({ $0.toFloatingPointDivision() })
            return NSExpression(block: expressionBlock, arguments: newArgs)
        case .constantValue, .anyKey:
        break // Nothing to do here
        case .evaluatedObject, .variable, .keyPath:
            // FIXME: These should probably be wrapped in blocks like the one
            // used in the `.function` case.
            break
        @unknown default:
            return self
        }
        return self
    }
}

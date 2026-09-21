/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.expressions.scoping

import nl.esi.xtext.expressions.expression.ExpressionFunctionCall
import nl.esi.xtext.expressions.expression.FunctionDecl
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IScope

import static extension nl.esi.xtext.expressions.utilities.ExpressionsUtilities.*
import static extension nl.esi.xtext.types.utilities.TypeUtilities.*

/**
 * Custom scope for function call resolution with three-phase matching strategy:
 * 1. Exact match: name + argument count + compatible types
 * 2. Size match: name + argument count (enables "type mismatch" errors)
 * 3. Name match: any overload (enables "wrong argument count" errors)
 * 
 * Fallback strategy provides specific error messages rather than generic "function not found".
 *
 * A cache is used for retrieval of parent IObjectDescriptions as they are eaten when iterating 
 * and this scope provider potentially does multiple calls.
 */
@FinalFieldsConstructor
class FunctionOverloadScope implements IScope {

    val IScope parent
    val ExpressionFunctionCall context

    override getAllElements() {
        parent.getAllElements()
    }

    override getElements(QualifiedName name) {
        val elements = parent.getElements(name).toList

        // Checks if function matches by argument count only
        val sizeMatches = elements.filter[functionDecl.params.size == context.args.size].toList
        if (sizeMatches.isEmpty) {
            // Phase 3: Name match - enables wrong argument count errors
            return elements
        }

        val exactMatches = sizeMatches.filter [
            // Checks if function matches by name, argument count, and all parameter types
            for (var i = 0; i < functionDecl.params.size; i++) {
                val param = functionDecl.params.get(i)
                val arg = context.args.get(i)
                val actualType = param.type.inferActualType(arg)?.typeObject
                val argType = typeOf(arg)
                if (!argType.subTypeOf(actualType)) {
                    return false
                }
            }
            return true
        ].toList
        if (exactMatches.isEmpty) {
            // Phase 2: Size match (name + arity) - enables type mismatch errors
            return sizeMatches
        }

        // Phase 1: Exact match (name + arity + types)
        return exactMatches
    }

    private def FunctionDecl getFunctionDecl(IEObjectDescription desc) {
        return desc.EObjectOrProxy as FunctionDecl
    }

    override getElements(EObject object) {
        return getAllElements().filter[EObjectOrProxy == object]
    }

    override getSingleElement(QualifiedName name) {
        return getElements(name).head
    }

    override getSingleElement(EObject object) {
        return getElements(object).head
    }
}

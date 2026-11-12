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

import java.util.List
import nl.esi.xtext.expressions.expression.Expression
import nl.esi.xtext.expressions.expression.NamedArgument
import nl.esi.xtext.expressions.expression.ParameterizedDecl
import nl.esi.xtext.expressions.expression.ParameterizedRef
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IScope

import static extension nl.esi.xtext.expressions.utilities.ExpressionsUtilities.*
import static extension nl.esi.xtext.types.utilities.TypeUtilities.*

/**
 * Scope that resolves overloaded {@link ParameterizedDecl}s (e.g. functions) based on the
 * arguments of a call, using a three-phase matching strategy:
 * 1. Exact match: name + argument count + compatible types
 * 2. Size match: name + argument count (enables "type mismatch" errors)
 * 3. Name match: any overload (enables "wrong argument count" errors)
 * 
 * Fallback strategy provides specific error messages rather than generic "declaration not found".
 *
 * Both positional and named arguments are taken into account: the argument count includes named arguments,
 * and named arguments are bound to parameters by name (positional arguments by index) before their types are checked.
 *
 * The scope only depends on {@link ParameterizedDecl} and the arguments, so other languages
 * can reuse it for their own parameterized declarations, e.g.
 * {@code new ParameterizedDeclOverloadScope(super.getScope(context, reference), context)} for a {@link ParameterizedRef}.
 * Candidates that are not a {@link ParameterizedDecl} never match by size or type.
 */
class ParameterizedDeclOverloadScope implements IScope {

    val IScope parent
    val List<Expression> args
    val List<NamedArgument> namedArgs

    new(IScope parent, List<Expression> args) {
        this(parent, args, emptyList)
    }

    new(IScope parent, List<Expression> args, List<NamedArgument> namedArgs) {
        this.parent = parent
        this.args = args
        this.namedArgs = namedArgs
    }

    new(IScope parent, ParameterizedRef context) {
        this(parent, context.args, context.namedArgs)
    }

    override getAllElements() {
        parent.getAllElements()
    }

    override getElements(QualifiedName name) {
        val elements = parent.getElements(name).toList

        // Checks if declaration matches by argument count only (positional + named)
        val argCount = args.size + namedArgs.size
        val sizeMatches = elements.filter[
            val decl = parameterizedDecl
            decl !== null && decl.params.size == argCount
        ].toList
        if (sizeMatches.isEmpty) {
            // Phase 3: Name match - enables wrong argument count errors
            return elements
        }

        val exactMatches = sizeMatches.filter [
            // Checks if declaration matches by name, argument count, argument names, and all parameter types
            val params = parameterizedDecl.params
            val boundArgs = parameterizedDecl.bindArguments(args, namedArgs)
            if (boundArgs === null) {
                return false
            }
            for (var i = 0; i < params.size; i++) {
                val param = params.get(i)
                val arg = boundArgs.get(i)
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

    private def ParameterizedDecl getParameterizedDecl(IEObjectDescription desc) {
        val obj = desc.EObjectOrProxy
        return obj instanceof ParameterizedDecl ? obj : null
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

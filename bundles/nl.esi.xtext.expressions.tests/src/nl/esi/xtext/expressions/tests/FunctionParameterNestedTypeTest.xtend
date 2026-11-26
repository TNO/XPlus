/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.expressions.tests

import com.google.inject.Inject
import nl.esi.xtext.common.lang.utilities.EcoreUtil3
import nl.esi.xtext.expressions.expression.ExpressionModel
import nl.esi.xtext.expressions.expression.FunctionDecl
import nl.esi.xtext.types.types.RecordTypeDecl
import nl.esi.xtext.types.types.TypeReference
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.^extension.ExtendWith

import static org.junit.jupiter.api.Assertions.*

/**
 * Tests that nested type declarations (see {@link nl.esi.xtext.types.types.RecordTypeDecl#getTypes})
 * work correctly when used (via their qualified name) as the type of a function parameter or as a
 * function's return type, and when used as the type of a variable passed as an argument in a
 * function call. Also verifies that the unqualified (shorthand) name of a nested type does *not*
 * resolve when used outside of its enclosing record's declaration chain, even if that simple name
 * happens to be unique across the whole program.
 */
@ExtendWith(InjectionExtension)
@InjectWith(ExpressionInjectorProvider)
class FunctionParameterNestedTypeTest {

    @Inject ParseHelper<ExpressionModel> parseHelper

    private def ExpressionModel parse(String model) {
        val result = parseHelper.parse(model)
        assertNotNull(result)
        EcoreUtil3.resolveAll(result)
        return result
    }

    private def FunctionDecl function(ExpressionModel model, String name) {
        val function = model.functions.findFirst[it.name == name]
        assertNotNull(function, '''Function «name» not found''')
        return function
    }

    @Test
    def void qualifiedNestedTypeAsParameterTypeResolves() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
                int a
            }
            function void handle(A.B input)
        ''')
        assertTrue(model.eResource.errors.isEmpty,
            '''Unexpected errors: «model.eResource.errors.join(", ")»''')

        val parameterType = model.function('handle').params.get(0).type as TypeReference
        assertNotNull(parameterType.type)
        assertFalse(parameterType.type.eIsProxy, 'Reference to A.B should have resolved')
        assertEquals('B', parameterType.type.name)
        assertTrue(parameterType.type.eContainer instanceof RecordTypeDecl)
    }

    @Test
    def void qualifiedNestedTypeAsReturnTypeResolves() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
            }
            function A.B create()
        ''')
        assertTrue(model.eResource.errors.isEmpty,
            '''Unexpected errors: «model.eResource.errors.join(", ")»''')

        val returnType = model.function('create').returnType as TypeReference
        assertNotNull(returnType.type)
        assertFalse(returnType.type.eIsProxy, 'Reference to A.B should have resolved')
        assertEquals('B', returnType.type.name)
    }

    @Test
    def void nestedTypeShorthandAsParameterTypeWithNestedFunctionResolves() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
                function void handle(B input)
            }
        ''')
        assertFalse(model.eResource.errors.isEmpty, 'Expected a linking error for unqualified B used outside its enclosing record')
    }

    @Test
    def void nestedTypeShorthandAsParameterTypeDoesNotResolve() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
            }
            function void handle(B input)
        ''')
        assertFalse(model.eResource.errors.isEmpty, 'Expected a linking error for unqualified B used outside its enclosing record')
    }


    @Test
    def void functionCallWithQualifiedNestedTypeArgumentValidates() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
                int a
            }
            function A.B identity(A.B input)
            A.B b = A.B { id = 1 }
            A.B result = identity(b)
        ''')
        assertTrue(model.eResource.errors.isEmpty,
            '''Unexpected parsing errors: «model.eResource.errors.join(", ")»''')
        EcoreUtil3.validate(model)
    }
}

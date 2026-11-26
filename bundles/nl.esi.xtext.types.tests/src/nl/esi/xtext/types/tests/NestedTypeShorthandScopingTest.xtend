/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.types.tests

import com.google.inject.Inject
import nl.esi.xtext.types.types.RecordField
import nl.esi.xtext.types.types.RecordTypeDecl
import nl.esi.xtext.types.types.TypeReference
import nl.esi.xtext.types.types.TypesModel
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.^extension.ExtendWith

import static org.junit.jupiter.api.Assertions.*
import nl.esi.xtext.common.lang.utilities.EcoreUtil3

/**
 * Tests the shorthand (unqualified) name resolution for nested type declarations,
 * as implemented in {@link nl.esi.xtext.types.scoping.TypesScopeProvider}.
 */
@ExtendWith(InjectionExtension)
@InjectWith(TypesInjectorProvider)
class NestedTypeShorthandScopingTest {

    @Inject ParseHelper<TypesModel> parseHelper

    private def TypesModel parse(String model) {
        val result = parseHelper.parse(model)
        assertNotNull(result)
        EcoreUtil3.resolveAll(result)
        return result
    }

    private def TypeReference fieldType(TypesModel model, String recordName, String fieldName) {
        val record = model.types.filter(RecordTypeDecl).findFirst[name == recordName]
        assertNotNull(record, '''Record «recordName» not found''')
        val field = record.fields.findFirst[name == fieldName] as RecordField
        assertNotNull(field, '''Field «fieldName» not found in «recordName»''')
        return field.type as TypeReference
    }

    @Test
    def void qualifiedNameAlwaysResolves() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
                A.B b
            }
        ''')
        assertTrue(model.eResource.errors.isEmpty,
            '''Unexpected errors: «model.eResource.errors.join(", ")»''')
        val type = model.fieldType('A', 'b')
        assertNotNull(type.type)
        assertEquals('B', type.type.name)
    }

    @Test
    def void uniqueNestedTypeShorthandOutsideEnclosingRecordDoesNotResolve() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
            }
            record C {
                B b
            }
        ''')
        // Even though B is unique across the whole program, a bare "B" reference from outside
        // A (its enclosing record) should not resolve via a global-uniqueness shorthand; it
        // must be qualified as A.B instead.
        assertFalse(model.eResource.errors.isEmpty, 'Expected a linking error for unqualified B used outside its enclosing record')
    }

    @Test
    def void ambiguousNestedTypeShorthandDoesNotResolve() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
            }
            record D {
                record B {
                    int id
                }
            }
            record C {
                B b
            }
        ''')
        // Ambiguous shorthand reference should produce a linking error
        assertFalse(model.eResource.errors.isEmpty, 'Expected a linking error for ambiguous shorthand B')
    }

    @Test
    def void localNestedTypeShorthandResolvesDespiteAmbiguousGlobalName() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
                B b
            }
            record D {
                record B {
                    int id
                }
            }
        ''')
        // Even though B is ambiguous at the global level (A.B and D.B both exist), a bare "B"
        // reference from inside A itself should resolve to A's own nested B, like an unqualified
        // nested class name resolves to the closest enclosing declaration in e.g. Java.
        assertTrue(model.eResource.errors.isEmpty,
            '''Unexpected errors: «model.eResource.errors.join(", ")»''')
        val type = model.fieldType('A', 'b')
        assertNotNull(type.type)
        assertFalse(type.type.eIsProxy, 'Reference to B should have resolved')
        assertEquals('B', type.type.name)
        val enclosing = type.type.eContainer
        assertTrue(enclosing instanceof RecordTypeDecl, 'B should be nested in a record')
        assertEquals('A', (enclosing as RecordTypeDecl).name, 'B should resolve to the one nested in A, not D')
    }

    @Test
    def void nestedNestedTypeShorthandResolvesToClosestEnclosingDeclaration() {
        val model = parse('''
            record A {
                record B {
                    int id
                }
                record C {
                    record B {
                        string tag
                    }
                    B b
                }
            }
        ''')
        // Inside A.C, the bare "B" reference should resolve to the closest enclosing declaration,
        // i.e. A.C.B, not the more distant A.B.
        assertTrue(model.eResource.errors.isEmpty,
            '''Unexpected errors: «model.eResource.errors.join(", ")»''')
        val recordA = model.types.filter(RecordTypeDecl).findFirst[name == 'A']
        assertNotNull(recordA, 'Record A not found')
        val recordC = recordA.types.filter(RecordTypeDecl).findFirst[name == 'C']
        assertNotNull(recordC, 'Record A.C not found')
        val field = recordC.fields.findFirst[name == 'b'] as RecordField
        assertNotNull(field, 'Field b not found in A.C')
        val type = field.type as TypeReference
        assertNotNull(type.type)
        assertFalse(type.type.eIsProxy, 'Reference to B should have resolved')
        assertEquals('B', type.type.name)
        assertSame(recordC, type.type.eContainer, 'B should resolve to the one nested in A.C, not A')
    }
}

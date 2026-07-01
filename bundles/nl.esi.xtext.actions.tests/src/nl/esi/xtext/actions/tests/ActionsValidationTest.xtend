/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.actions.tests

import com.google.inject.Inject
import nl.esi.xtext.actions.actions.ActionModel
import nl.esi.xtext.common.lang.utilities.EcoreUtil3
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.^extension.ExtendWith

@ExtendWith(InjectionExtension)
@InjectWith(ActionsInjectorProvider)
class ActionsValidationTest {
    @Inject
    ParseHelper<ActionModel> actionParseHelper

    // === Assignment Action Tests ===

    @Test
    def void testAssignmentAction() {
        validate('''
            int x
            x := 5
        ''')
    }

    @Test
    def void testAssignmentActionIncrement() {
        validate('''
            int x
            x := x + 1
        ''')
    }

    // === For Action Tests ===

    @Test
    def void testForAction() {
        validate('''
            int[] numbers = <int[]>[1, 2, 3]
            int total
            for int n in numbers
                do
                    total := total + n
            end-for
        ''')
    }

    // === If Action Tests ===

    @Test
    def void testIfActionSimple() {
        validate('''
            int x
            x := 10
            int result
            if x > 5
            then
                result := 1
            fi
        ''')
    }

    @Test
    def void testIfActionWithElse() {
        validate('''
            int x
            x := 10
            int result
            if x > 5
            then
                result := 1
            else
                result := 0
            fi
        ''')
    }

    // === Record Field Assignment Action Tests ===

    @Test
    def void testRecordFieldAssignment() {
        validate('''
            record Point { int x, int y }
            Point p = Point{x = 0, y = 0}
            p.x := 10
            p.y := 20
        ''')
    }

    @Test
    def void testNestedRecordFieldAssignment() {
        validate('''
            record Inner { int value }
            record Outer { Inner inner }
            Inner i = Inner{value = 0}
            Outer o = Outer{inner = i}
            o.inner.value := 42
        ''')
    }

    // === Function Call Action Tests ===

    @Test
    def void testFunctionCallAction() {
        validate('''
            function int sum(int[] values)
            int[] data = <int[]>[1, 2, 3]
            sum(data)
        ''')
    }

    private def validate(String text) {
        val result = actionParseHelper.parse(text)

        Assertions.assertNotNull(result)
        var errors = result.eResource.errors
        Assertions.assertTrue(errors.isEmpty, '''Unexpected parsing errors: «errors.join(", ")»''')
        EcoreUtil3.validate(result)
        errors = result.eResource.errors
        Assertions.assertTrue(errors.isEmpty, '''Unexpected validation errors: «errors.join(", ")»''')
        // test serialization
        EcoreUtil3.serialize(result)
    }
}

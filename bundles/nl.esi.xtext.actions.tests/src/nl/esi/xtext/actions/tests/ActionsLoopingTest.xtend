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
import nl.esi.xtext.expressions.evaluation.ExpressionEvaluator
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.^extension.ExtendWith

@ExtendWith(InjectionExtension)
@InjectWith(ActionsInjectorProvider)
class ActionsLoopingTest {
    @Inject
    ParseHelper<ActionModel> actionParseHelper
    
    @Inject
    ExpressionEvaluator evaluator
    

    // === Assignment Action Tests ===

    @Test
    def void testForWithIntRange() {
        validate('''
            int[] my_list = <int[]>[]
            int[] value = <int[]>[ 1,2,3,4] 
            int window_size = 2
            for int idx in range(0,size(value), 2) do
               my_list := add(my_list, idx*window_size)
               my_list := add(my_list, idx*window_size +1)
            end-for
            int[] result = my_list
            ''')
    }

    @Test
    def void testForWithRange() {
        validate('''
            int[] my_list = <int[]>[]
            int[] value = <int[]>[ 1,2,3,4] 
            int window_size = 2
            for int idx in range(0,size(value)/2) do
               my_list := add(my_list, 2*idx*window_size)
               my_list := add(my_list, 2*idx*window_size +1)
            end-for
            ''')
    }

    private def validate(String text) {
        val result = actionParseHelper.parse(text)

        Assertions.assertNotNull(result)
        var errors = result.eResource.errors
        errors.forEach[println]
        Assertions.assertTrue(errors.isEmpty, '''Unexpected parsing errors: «errors.join(", ")»''')
        EcoreUtil3.validate(result)
        errors = result.eResource.errors
        Assertions.assertTrue(errors.isEmpty, '''Unexpected validation errors: «errors.join(", ")»''')
        // test serialization
        EcoreUtil3.serialize(result)
        //test evaluation
        eval(text)
    }
    
        protected def String eval(String input) {
        val model = actionParseHelper.parse(input)
        Assertions.assertTrue(model.eResource.errors.isEmpty, '''Unexpected errors in input: «model.eResource.errors.join(", ")»''')
        EcoreUtil3.validate(model)
        Assertions.assertEquals(model.variables.size, model.variables.map[variable.name].toSet.size, 'Variables cannot be declared multiple times')
        val context = model.variables.toMap([variable], [expression])
        for (assignment : model.variables.reject[expression === null]) {
            assignment.expression = evaluator.evaluate(assignment.expression) [ variable |
                return context.get(variable)
            ]
        }
        EcoreUtil3.serialize(model)
    }
    
}

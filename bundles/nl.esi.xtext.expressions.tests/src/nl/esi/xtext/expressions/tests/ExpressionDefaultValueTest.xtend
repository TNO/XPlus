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
import nl.esi.xtext.expressions.expression.ExpressionConstantBool
import nl.esi.xtext.expressions.expression.ExpressionConstantInt
import nl.esi.xtext.expressions.expression.ExpressionConstantReal
import nl.esi.xtext.expressions.expression.ExpressionConstantString
import nl.esi.xtext.expressions.expression.ExpressionMinus
import nl.esi.xtext.expressions.expression.ExpressionModel
import nl.esi.xtext.expressions.expression.ExpressionRecord
import nl.esi.xtext.types.BasicTypes
import nl.esi.xtext.types.types.RecordTypeDecl
import nl.esi.xtext.types.types.SimpleTypeDecl
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.extensions.InjectionExtension
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.^extension.ExtendWith

import static extension nl.esi.xtext.expressions.utilities.ExpressionsUtilities.*

/**
 * Tests {@link nl.esi.xtext.expressions.utilities.ExpressionsUtilities#createDefaultValue} and
 * {@link nl.esi.xtext.expressions.utilities.ExpressionsUtilities#getDefaultValueExpression(SimpleTypeDecl)},
 * i.e. the evaluation of default values declared on (or derived for) {@code SimpleTypeDecl}s.
 */
@ExtendWith(InjectionExtension)
@InjectWith(ExpressionInjectorProvider)
class ExpressionDefaultValueTest {
    @Inject
    ParseHelper<ExpressionModel> parseHelper

    @Test
    def void builtInTypesHaveHardcodedDefaults() {
        val intDefault = BasicTypes.getIntType().createDefaultValue[true]
        Assertions.assertTrue(intDefault instanceof ExpressionConstantInt)
        Assertions.assertEquals(0L, (intDefault as ExpressionConstantInt).value)

        val realDefault = BasicTypes.getRealType().createDefaultValue[true]
        Assertions.assertTrue(realDefault instanceof ExpressionConstantReal)
        Assertions.assertEquals(0.0, (realDefault as ExpressionConstantReal).value, 0.0)

        val boolDefault = BasicTypes.getBoolType().createDefaultValue[true]
        Assertions.assertTrue(boolDefault instanceof ExpressionConstantBool)
        Assertions.assertEquals(false, (boolDefault as ExpressionConstantBool).value)

        val stringDefault = BasicTypes.getStringType().createDefaultValue[true]
        Assertions.assertTrue(stringDefault instanceof ExpressionConstantString)
        Assertions.assertEquals("", (stringDefault as ExpressionConstantString).value)
    }

    @Test
    def void declaredDefaultValueIsUsed() {
        val model = parse('''
            type AType based on int = 3
        ''')
        val aType = model.simpleType('AType')

        val defaultValue = aType.createDefaultValue[true]
        Assertions.assertTrue(defaultValue instanceof ExpressionConstantInt)
        Assertions.assertEquals(3L, (defaultValue as ExpressionConstantInt).value)

        // The returned expression must be a copy, not the declared expression instance itself,
        // so it can safely be attached elsewhere (e.g. as a field value in a generated record).
        Assertions.assertNotSame(aType.defaultValueExpression, defaultValue)
    }

    @Test
    def void declaredDefaultValueCanBeNegative() {
        val model = parse('''
            type NegType based on int = -5
        ''')
        val negType = model.simpleType('NegType')

        val defaultValue = negType.createDefaultValue[true]
        Assertions.assertTrue(defaultValue instanceof ExpressionMinus)
        val sub = (defaultValue as ExpressionMinus).sub
        Assertions.assertTrue(sub instanceof ExpressionConstantInt)
        Assertions.assertEquals(5L, (sub as ExpressionConstantInt).value)
    }

    @Test
    def void defaultValueIsInheritedFromBaseType() {
        val model = parse('''
            type AType based on int = 3
            type BType based on AType
        ''')
        val bType = model.simpleType('BType')

        // BType declares no default of its own: it must fall back to AType's declared default.
        val defaultValue = bType.createDefaultValue[true]
        Assertions.assertTrue(defaultValue instanceof ExpressionConstantInt)
        Assertions.assertEquals(3L, (defaultValue as ExpressionConstantInt).value)
    }

    @Test
    def void typeWithoutBaseAndWithoutDefaultFallsBackToEmptyString() {
        val model = parse('''
            type Plain
        ''')
        val plain = model.simpleType('Plain')

        val defaultValue = plain.createDefaultValue[true]
        Assertions.assertTrue(defaultValue instanceof ExpressionConstantString)
        Assertions.assertEquals("", (defaultValue as ExpressionConstantString).value)
    }

    @Test
    def void recordFieldFallsBackToItsTypesDefaultValueWhenOmitted() {
        val model = parse('''
            type AType based on int = 3
            record R {
                AType a
                int b = 10
            }
        ''')
        val recordType = model.types.filter(RecordTypeDecl).findFirst[name == 'R']
        Assertions.assertNotNull(recordType)

        val defaultValue = recordType.createDefaultValue[true]
        Assertions.assertTrue(defaultValue instanceof ExpressionRecord)
        val record = defaultValue as ExpressionRecord

        // Field 'a' has no own default: it falls back to its type's (AType) declared default.
        val aValue = record.fields.findFirst[recordField.name == 'a'].exp
        Assertions.assertTrue(aValue instanceof ExpressionConstantInt)
        Assertions.assertEquals(3L, (aValue as ExpressionConstantInt).value)

        // Field 'b' declares its own default, which takes precedence.
        val bValue = record.fields.findFirst[recordField.name == 'b'].exp
        Assertions.assertTrue(bValue instanceof ExpressionConstantInt)
        Assertions.assertEquals(10L, (bValue as ExpressionConstantInt).value)
    }

    @Test
    def void generateDefaultValueForBuiltInTypes() {
        Assertions.assertEquals("0", BasicTypes.getIntType().generateDefaultValue[true].toString)
        Assertions.assertEquals("0.0", BasicTypes.getRealType().generateDefaultValue[true].toString)
        Assertions.assertEquals("true", BasicTypes.getBoolType().generateDefaultValue[true].toString)
        Assertions.assertEquals('''""'''.toString, BasicTypes.getStringType().generateDefaultValue[true].toString)
    }

    @Test
    def void generateDefaultValueUsesDeclaredDefault() {
        val model = parse('''
            type AType based on int = 3
        ''')
        val aType = model.simpleType('AType')

        Assertions.assertEquals("3", aType.generateDefaultValue[true].toString)
    }

    @Test
    def void generateDefaultValueRendersNegativeConstant() {
        val model = parse('''
            type NegType based on int = -5
        ''')
        val negType = model.simpleType('NegType')

        Assertions.assertEquals("-5", negType.generateDefaultValue[true].toString)
    }

    @Test
    def void generateDefaultValueEscapesStringDefault() {
        val model = parse('''
            type Quoted based on string = "She said \"hi\" and used a \\ backslash"
        ''')
        val quoted = model.simpleType('Quoted')

        Assertions.assertEquals('''"She said \"hi\" and used a \\ backslash"'''.toString, quoted.generateDefaultValue[true].toString)
    }

    @Test
    def void generateDefaultValueIsInheritedFromBaseType() {
        val model = parse('''
            type AType based on int = 3
            type BType based on AType
        ''')
        val bType = model.simpleType('BType')

        // BType declares no default of its own: it must fall back to AType's declared default.
        Assertions.assertEquals("3", bType.generateDefaultValue[true].toString)
    }

    @Test
    def void generateDefaultValueFallsBackToEmptyStringWithoutBaseOrDefault() {
        val model = parse('''
            type Plain
        ''')
        val plain = model.simpleType('Plain')

        // Unlike createDefaultValue (which creates an actual ExpressionConstantString with value ""),
        // generateDefaultValue's defensive fallback for an unrecognized/base-less SimpleTypeDecl simply
        // yields empty text - there is no sensible concrete syntax to emit for such an ill-formed model.
        Assertions.assertEquals("", plain.generateDefaultValue[true].toString)
    }

    @Test
    def void generateDefaultValueForRecordUsesFieldDefaultsOrFallsBackToType() {
        val model = parse('''
            type AType based on int = 3
            record R {
                AType a
                int b = 10
            }
        ''')
        val recordType = model.types.filter(RecordTypeDecl).findFirst[name == 'R']
        Assertions.assertNotNull(recordType)

        val generated = recordType.generateDefaultValue[true].toString

        // Field 'a' has no own default: it falls back to its type's (AType) declared default.
        Assertions.assertTrue(generated.contains("a = 3"), '''Expected "a = 3" in: «generated»''')

        // Field 'b' declares its own default, which takes precedence.
        Assertions.assertTrue(generated.contains("b = 10"), '''Expected "b = 10" in: «generated»''')
    }

    private def ExpressionModel parse(CharSequence text) {
        val model = parseHelper.parse(text)
        Assertions.assertNotNull(model)
        val errors = model.eResource.errors
        Assertions.assertTrue(errors.isEmpty, '''Unexpected parsing errors: «errors.join(", ")»''')
        EcoreUtil3.validate(model)
        return model
    }

    private def SimpleTypeDecl simpleType(ExpressionModel model, String name) {
        val type = model.types.filter(SimpleTypeDecl).findFirst[it.name == name]
        Assertions.assertNotNull(type, '''Type «name» not found''')
        return type
    }
}

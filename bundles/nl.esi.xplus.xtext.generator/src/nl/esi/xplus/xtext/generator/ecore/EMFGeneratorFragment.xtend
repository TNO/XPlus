/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xplus.xtext.generator.ecore

import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.xtext.generator.ecore.EMFGeneratorFragment2
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class EMFGeneratorFragment extends EMFGeneratorFragment2 {
    
    boolean operationReflection = false;
    
    override protected getGenModel(ResourceSet rs, Grammar grammar) {
        val genModel = super.getGenModel(rs, grammar)
        genModel.operationReflection = true
        return genModel
    }
    
    
}

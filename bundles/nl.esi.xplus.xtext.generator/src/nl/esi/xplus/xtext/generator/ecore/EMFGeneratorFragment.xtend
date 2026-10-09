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

import org.eclipse.emf.codegen.ecore.genmodel.GenModel
import org.eclipse.emf.codegen.ecore.genmodel.GenModelPackage
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ContentHandler
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.xmi.impl.EcoreResourceFactoryImpl
import org.eclipse.emf.mwe.utils.GenModelHelper
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.GeneratedMetamodel
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.xtext.generator.ecore.EMFGeneratorFragment2

@Accessors
class EMFGeneratorFragment extends EMFGeneratorFragment2 {
    
    boolean operationReflection = false
    
    /**
     * Path to an external GenModel file to use for code generation.
     * When set, code generation will proceed even if the grammar has no generated metamodels.
     * Example: "platform:/resource/${baseName}/model/Base.genmodel"
     * 
     * Note: Requires platformUri to be set in StandaloneSetup bean in the MWE2 workflow
     * so that platform:/resource/ URIs can be properly resolved.
     */
    @Accessors(PUBLIC_SETTER)
    String externalGenModelPath
    
    override protected getGenModel(ResourceSet rs, Grammar grammar) {
        val genModel = super.getGenModel(rs, grammar)
        genModel.operationReflection = true
        return genModel
    }
    
    override generate() {
        // If an external genmodel path is provided, use it for code generation
        // even if the grammar has no generated metamodels
        if (externalGenModelPath !== null) {
            if (grammar.metamodelDeclarations.filter(GeneratedMetamodel).empty) {
                generateFromExternalGenModel()
                return
            }
        }
        // use the parent implementation which requires generated metamodels
        super.generate()
    }
    
    /**
     * Generates EMF code from an external GenModel file, bypassing the need for
     * Xtext-generated metamodels in the grammar.
     */
    protected def void generateFromExternalGenModel() {
        try {
            if (!Resource.Factory.Registry.INSTANCE.extensionToFactoryMap.containsKey('genmodel'))
                Resource.Factory.Registry.INSTANCE.extensionToFactoryMap.put('genmodel', new EcoreResourceFactoryImpl)
            GenModelPackage.eINSTANCE.getGenAnnotation()
            
            // Create a new resource set for loading the genmodel
            val resourceSet = new XtextResourceSet
            
            // Create URI from the path (platformUri in StandaloneSetup handles the mapping)
            val genModelUri = URI.createURI(externalGenModelPath)
            
            
            // Load the genmodel
            val genModelFile = resourceSet.createResource(genModelUri, ContentHandler.UNSPECIFIED_CONTENT_TYPE)
            if (!resourceSet.URIConverter.exists(genModelUri, null)) {
                System.err.println('External GenModel file not found at: ' + externalGenModelPath)
                return
            }
            
            genModelFile.load(null)
            val genModel = if (genModelUri.hasFragment) {
                genModelFile.getEObject(genModelUri.fragment) as GenModel
            } else {
                genModelFile.contents.head as GenModel
            }
            
            if (genModel === null) {
                System.err.println('Could not load GenModel from: ' + externalGenModelPath)
                return
            }
            
            // Make sure everything is set
            genModel.reconcile()
            
            // Execute the emf generator (using parent's protected doGenerate method)
            doGenerate(genModel)
            
            addProjectContributionsFromGenModel(genModel)
            // reregister
            new GenModelHelper().registerGenModel(new XtextResourceSet, genModelUri)
            
            
        } catch (Exception e) {
            System.err.println('Failed to execute EMF generator with external GenModel')
            e.printStackTrace
        }
    }
    
    /**
     * Adds project contributions based on the external GenModel's packages.
     */
    protected def void addProjectContributionsFromGenModel(GenModel genModel) {
        if (projectConfig.runtime.pluginXml !== null) {
            projectConfig.runtime.pluginXml.entries += '''
                <extension point="org.eclipse.emf.ecore.generated_package">
                    «FOR genPkg : genModel.genPackages»
                        <package
                            uri = "«genPkg.getEcorePackage.nsURI»"
                            class = "«genPkg.qualifiedPackageInterfaceName»"
                            genModel = "«externalGenModelPath.relativePath»" />
                    «ENDFOR»
                </extension>
            '''
        }
        if (projectConfig.runtime.manifest !== null) {
            projectConfig.runtime.manifest.requiredBundles.addAll('org.eclipse.emf.ecore', 'org.eclipse.emf.common')
        }
    }
}
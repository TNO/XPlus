/**
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.types.generator

import java.util.HashMap
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.generator.AbstractFileSystemAccess
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.OutputConfiguration

class XPlusFileSystemAccess implements IFileSystemAccess {

	final public static String STATISTICS_FOLDER = "statistics"
	final public static String FOLDER_UP = "../"
	
	final IFileSystemAccess2 fileSystemAccess	
	public String outputConfiguration = DEFAULT_OUTPUT
	String generationFolder	
	
	final public static String XPLUS_OUTPUT_ID = "outputXPlusGen"
	final public static String XPLUS_OUTPUT_FOLDER = "./xplus-gen"
	public static val OutputConfiguration XPLUS_OUTPUT_CONF = {
		val config = new OutputConfiguration(XPLUS_OUTPUT_ID)
		config.outputDirectory = XPLUS_OUTPUT_FOLDER
		config.description = XPLUS_OUTPUT_FOLDER
		config.createOutputDirectory = true
		config.canClearOutputDirectory = true
		config.cleanUpDerivedResources = true
		return config
	}

	new(String generationFolder, IFileSystemAccess2 fsa) {
		this.fileSystemAccess = fsa
		this.generationFolder = generationFolder		
	}

	new(String generationFolder, XPlusFileSystemAccess xplusFileSystemAccess) {
		this.fileSystemAccess = xplusFileSystemAccess.IFileSystemAccess
		this.generationFolder = xplusFileSystemAccess.getGenerationFolder + generationFolder
	}

	new(IFileSystemAccess2 fsa) {
		this.fileSystemAccess = fsa
		this.generationFolder = ""
	}
	
	new(String generationFolder, IFileSystemAccess2 fsa, boolean xplusGen) {
		this.fileSystemAccess = fsa		
		this.generationFolder = generationFolder
		if(xplusGen) {			
			setOutPutXPlusGen			
		}	
	}

	override deleteFile(String fileName) {
		fileSystemAccess.deleteFile(generationFolder + fileName, outputConfiguration)
	}

	override generateFile(String fileName, CharSequence contents) {
		generateFile(fileName, outputConfiguration, contents)
	}

	override generateFile(String fileName, String outputConfigurationName, CharSequence contents) {
		fileSystemAccess.generateFile(generationFolder + fileName, outputConfigurationName, contents)
	}

	def String generateFileLocation(String fileName, CharSequence contents) {
		generateFile(fileName, contents)
		return generationFolder + fileName
	}

	def getIFileSystemAccess() {
		fileSystemAccess
	}

	def getGenerationFolder() {
		generationFolder
	}

	def addFolder(String additionalFolder) {
		val path =  if(!additionalFolder.endsWith("/")) additionalFolder + "/" else additionalFolder		
		new XPlusFileSystemAccess(path, this)
	}	

	def getRootPrefix() {
		val sb = new StringBuilder();
		for (var i = 0; i < URI.createFileURI(generationFolder).segments.size - 1; i++) {
			sb.append(FOLDER_UP)
		}
		return sb.toString
	}
	
	def setOutPutXPlusGen() {
		if (fileSystemAccess instanceof AbstractFileSystemAccess) {
			outputConfiguration = XPLUS_OUTPUT_ID
			val configurations = fileSystemAccess.outputConfigurations
			if (!configurations.containsKey(XPLUS_OUTPUT_ID)) {
				val newConfigurations = new HashMap(configurations)
				newConfigurations.put(XPLUS_OUTPUT_ID, XPLUS_OUTPUT_CONF)
				fileSystemAccess.outputConfigurations = newConfigurations
			}
		} else {
			generationFolder = FOLDER_UP + "xplus-gen/" + generationFolder
		}
	}

}

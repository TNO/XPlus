/**
 * Copyright (c) 2024, 2026 TNO-ESI
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xplus.emf.mwe.utils

import java.io.File
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.mwe.utils.StandaloneSetup

class XPlusStandAloneSetup extends StandaloneSetup {

    def addTryRegisterEcoreFile(String fileName) {
        try {
            val res = resourceSet.getResource(createURI(fileName), true);
            if (res === null) {
                return
            }
            addRegisterEcoreFile(fileName)

        } catch (Exception e) {
            // intentially ignored
        }
    }

    def addTryRegisterGenModelFile(String fileName) {
        try {
            val res = resourceSet.getResource(createURI(fileName), true);
            if (res === null) {
                return
            }
            addRegisterGenModelFile(fileName)
        } catch (Exception e) {
            // intentially ignored
        }
    }

    private def URI createURI(String path) {
        if (path === null) {
            throw new IllegalArgumentException();
        }

        val uri = URI.createURI(path);
        if (uri.isRelative()) {
            val resolvedURI = URI.createFileURI(new File(path).getAbsolutePath());
            return resolvedURI;
        }
        return uri;
    }

}

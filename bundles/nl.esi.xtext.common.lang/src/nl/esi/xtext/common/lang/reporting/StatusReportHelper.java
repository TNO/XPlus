/*
 * Copyright (c) 2024, 2026 TNO-ESI
 *
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package nl.esi.xtext.common.lang.reporting;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.eclipse.emf.common.util.BasicDiagnostic;
import org.eclipse.emf.common.util.Diagnostic;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.util.Diagnostician;
import org.eclipse.emf.ecore.util.EObjectValidator;
import org.eclipse.xtext.nodemodel.ICompositeNode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import nl.esi.xtext.common.lang.utilities.EcoreUtil3;


public class StatusReportHelper {
	
    /**
     * Gson instance for JSON serialization/deserialization.
     */
    private static final Gson GSON = new GsonBuilder()
        .setPrettyPrinting()
        .create();

	/**
	 * validates the given EObject.
	 * @see {@link EcoreUtil3#validate(EObject)}
	 */
	public static StatusReport validate(EObject eObject) {
		Diagnostician diagnostician = new Diagnostician();
		BasicDiagnostic diagnostics = diagnostician.createDefaultDiagnostic(eObject);
		Map<Object, Object> context = diagnostician.createDefaultContext();

		diagnostician.validate(eObject, diagnostics, context);
		return fromDiagnostic(diagnostics);
	}

	/**
	 * validate the given EObject and add it to the reports if not OK.
	 */
	public static void validate(List<StatusReport> reports,  EObject object)  {
		var report = validate(object);
		if(report.severity() != Severity.OK) {
			reports.add(report);
		}
	}

	/**
	 * validate the given resource
	 * @see {@link EcoreUtil3#validate(EObject)}
	 */
	public static StatusReport validate(Resource resource)  {
		Diagnostician diagnostician = new Diagnostician();
		BasicDiagnostic diagnostics = new BasicDiagnostic(EObjectValidator.DIAGNOSTIC_SOURCE, 0,
				"Diagnosis of " + resource.getURI(), new Object[] { resource });
		Map<Object, Object> context = diagnostician.createDefaultContext();

		for (EObject eObject : resource.getContents()) {
			diagnostician.validate(eObject, diagnostics, context);
		}
		
		return fromDiagnostic(diagnostics);

	}

	/**
	 * validate the given resource and add it to the reports if not OK.
	 * returns true if the resource an error exists in reports after validation.
	 */
	public static boolean validate(List<StatusReport> reports,  Resource resource)  {
		var report = validate(resource);
		if(report.severity() != Severity.OK) {
			reports.add(report);
		}
		return reports.stream().anyMatch(r->r.severity() == Severity.ERROR);
	}

    /**
     * Serializes this ValidationMessage to a JSON string using Gson.
     *
     * @return a JSON string representation of this ValidationMessage
     */
    public static String toJson(StatusReport validationMessage) {
        return GSON.toJson(validationMessage);
    }



    public static StatusReport fromJson(String jsonString) {
        return GSON.fromJson(jsonString, StatusReport.class);
	}

	/**
     * Generates a ValidationMessage from a Diagnostic instance, including Children.
     * 
     * Mapping:
     * - severity -> severity
     * - message -> message
     * - source -> source
     * - code -> code
     * - exception -> details (or null if none)
     * - children -> children (recursively converted)
     * - location -> startLine, endLine, offset, length, text (extracted from diagnostic data if available)
     *
     * @param diagnostic the diagnostic to convert
     * @return a new ValidationMessage based on the diagnostic
     */
    public static StatusReport fromDiagnostic(Diagnostic diagnostic) {
        if (diagnostic == null) {
            return null;
        }

        String details = null;
        Throwable exception = diagnostic.getException();
        if (exception != null) {
            StringBuilder sb = new StringBuilder();
            sb.append(exception.getClass().getName());
            if (exception.getMessage() != null) {
                sb.append(": ").append(exception.getMessage());
            }
            sb.append("\n");
            
            // Append stack trace (limited to 15 elements)
            StackTraceElement[] stackTrace = exception.getStackTrace();
            int limit = Math.min(stackTrace.length, 15);
            for (int i = 0; i < limit; i++) {
                sb.append("\tat ").append(stackTrace[i]).append("\n");
            }
            if (stackTrace.length > 15) {
                sb.append("\t... ").append(stackTrace.length - 15).append(" more\n");
            }
            
            details = sb.toString();
        }

        List<StatusReport> children = null;
        List<Diagnostic> diagnosticChildren = diagnostic.getChildren();
        if (diagnosticChildren != null && !diagnosticChildren.isEmpty()) {
            children = diagnosticChildren.stream()
                .map(StatusReportHelper::fromDiagnostic)
                .toList();
        }

        var source = extractSource(diagnostic);
        var node = extractLocationData(diagnostic);

        return new StatusReport(
            Severity.fromValue(diagnostic.getSeverity()),
            diagnostic.getMessage(),
            source,
            diagnostic.getCode(),
            details,
            node!= null ? node.getStartLine(): null,
    		node!= null ? node.getEndLine(): null,
			node!= null ? node.getOffset(): null,
			node!= null ? node.getLength(): null,
			node!= null ? node.getText(): null ,
            children
        );
    }

    /**
	 * Converts an exception to a StatusReport, including cause chain as children.
	 * Detects cycles in the cause chain to prevent infinite loops.
	 * 
	 * @param exception the exception to convert
     * @param linkedHashSet 
	 * @return a new StatusReport with the exception details and cause chain
	 */
	public static StatusReport fromException(Throwable exception, String userMessage, List<StatusReport> children) {
		return fromException(exception, userMessage, children, new LinkedHashSet<>());
	}

	public static StatusReport errorReport(String errorMessage, List<StatusReport> children) {
		return fromMessage(Severity.ERROR, errorMessage, children);
	}

	public static StatusReport warningReport( String errorMessage, List<StatusReport> children) {
		return fromMessage(Severity.WARNING, errorMessage, children);
	}

	public static StatusReport infoReport(String errorMessage, List<StatusReport> children) {
		return fromMessage(Severity.INFO, errorMessage, children);
	}

	private static StatusReport fromMessage(Severity severity, String errorMessage, List<StatusReport> children) {
		
		return new StatusReport(
			severity,
			errorMessage,
			null,  // source - unknown
			null,     // code - default
			null,  // details - none
			null,     // startLine - unknown
			null,     // endLine - unknown
			null,     // offset - unknown
			null,     // length - unknown
			null,    // text - unknown
			children
		);
	}

	/**
     * Extracts location information from a Diagnostic instance.
     * The location is derived from the diagnostic's data array, typically containing
     * EObject or Resource information.
     *
     * @param diagnostic the diagnostic to extract location from
     * @return a location string if available, null otherwise
     */
    private static String extractSource(Diagnostic diagnostic) {
        if (diagnostic == null) {
            return null;
        }

        List<?> data = diagnostic.getData();
        if (data != null && !data.isEmpty()) {
            Object firstData = data.get(0);
            if (firstData instanceof EObject eObject) {
                Resource resource = eObject.eResource();
                if (resource != null) {
                    return resource.getURI().toString();
                }
            } else if (firstData instanceof Resource resource) {
                return resource.getURI().toString();
            }
        }

        return null;
    }
    
	/**
	 * Gets detailed location information including line, column, offset
	 * 
	 * @param diagnostic The diagnostic to extract location from
	 * @return Object array [startLine, endLine, offset, length, text] with default
	 *         values if not available
	 */
	private static ICompositeNode extractLocationData(Diagnostic diagnostic) {
		if (diagnostic == null || diagnostic.getData() == null || diagnostic.getData().isEmpty()) {
			return null;
		}

		Object firstData = diagnostic.getData().get(0);

		if (firstData instanceof EObject eObject) {
			ICompositeNode node = NodeModelUtils.getNode(eObject);

			if (node != null) {
				return node;
			}
		}

		return null;
	}
	
	/**
	 * Internal method to convert exception with cycle detection.
	 * 
	 * @param exception the exception to convert
	 * @param seenExceptions set of already processed exceptions to detect cycles
	 * @return a new StatusReport with the exception details and cause chain
	 */
	private static StatusReport fromException(Throwable exception, String userMessage, List<StatusReport> children, Set<Throwable> seenExceptions) {
		if (exception == null) {
			return null;
		}
		
		// Check for cycle
		if (seenExceptions.contains(exception)) {
			return null;
		}
		
		seenExceptions.add(exception);
		
		// Build details string with class name and message
		StringBuilder details = new StringBuilder();
		details.append(exception.getClass().getName());
		if (exception.getMessage() != null) {
			details.append(": ").append(exception.getMessage());
		}
		details.append("\n");
		
		// Append stack trace (limited to 15 elements)
		StackTraceElement[] stackTrace = exception.getStackTrace();
		int limit = Math.min(stackTrace.length, 15);
		for (int i = 0; i < limit; i++) {
			details.append("\tat ").append(stackTrace[i]).append("\n");
		}
		if (stackTrace.length > 15) {
			details.append("\t... ").append(stackTrace.length - 15).append(" more\n");
		}
		
		// Process cause as child (if exists)
		List<StatusReport> allChildren = new ArrayList<StatusReport>();
		if (children != null) {
			allChildren.addAll(children);
		}
		Throwable cause = exception.getCause();
		if (cause != null) {
			StatusReport childReport = fromException(cause, null, null, seenExceptions);
			if (childReport != null) {
				allChildren.add(childReport);
			}
		}
		
		// Create StatusReport with defaults for unknown fields
		StringBuffer message = new StringBuffer();
		if (userMessage != null && !userMessage.isEmpty()) {
			message.append(userMessage).append("\n");
		}
		message.append(exception.getLocalizedMessage() != null ? exception.getLocalizedMessage() : exception.getClass().getSimpleName());
		return new StatusReport(
			Severity.ERROR,
			message.toString(),
			null,  // source - unknown
			null,     // code - default
			details.toString(),
			null,     // startLine - unknown
			null,     // endLine - unknown
			null,     // offset - unknown
			null,     // length - unknown
			null,    // text - unknown
			allChildren
		);
	}

}

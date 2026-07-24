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
import java.util.Set;

import org.eclipse.core.runtime.IStatus;
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
		var diagnostician = new Diagnostician();
		var diagnostics = diagnostician.createDefaultDiagnostic(eObject);
		var context = diagnostician.createDefaultContext();

		diagnostician.validate(eObject, diagnostics, context);
		return fromDiagnostic(diagnostics);
	}

	/**
	 * validate the given EObject and add it to the reports if not OK.
	 */
	public static void validate(List<StatusReport> reports,  EObject object)  {
		var report = validate(object);
		reports.add(report);
	}

	/**
	 * validate the given resource
	 * @see {@link EcoreUtil3#validate(EObject)}
	 */
	public static StatusReport validate(Resource resource)  {
		var diagnostician = new Diagnostician();
		var diagnostics = new BasicDiagnostic(EObjectValidator.DIAGNOSTIC_SOURCE, 0,
				"Diagnosis of " + resource.getURI(), new Object[] { resource });
		var context = diagnostician.createDefaultContext();

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
		if(report.getSeverityLevel() != Severity.OK) {
			reports.add(report);
		}
		return reports.stream().anyMatch(r->r.getSeverityLevel() == Severity.ERROR);
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
     * - code -> code
     * - exception -> details (or null if none)
     * - children -> children (recursively converted)
     * - location -> locations list (extracted from diagnostic data if available)
     *
     * @param diagnostic the diagnostic to convert
     * @return a new StatusReport based on the diagnostic
     */
    public static StatusReport fromDiagnostic(Diagnostic diagnostic) {
        if (diagnostic == null) {
            return null;
        }

        var exception = diagnostic.getException();

        List<StatusReport> children = null;
        var diagnosticChildren = diagnostic.getChildren();
        if (diagnosticChildren != null && !diagnosticChildren.isEmpty()) {
            children = diagnosticChildren.stream()
                .map(StatusReportHelper::fromDiagnostic)
                .toList();
        }

        var source = extractSource(diagnostic);
        var node = extractLocationData(diagnostic);
        
        List<Location> locations = null;
        if (node != null || source != null) {
            locations = new ArrayList<>();
            locations.add(new Location(
                source,
                node != null ? node.getStartLine() : null,
                node != null ? node.getEndLine() : null,
                node != null ? node.getOffset() : null,
                node != null ? node.getLength() : null,
                node != null ? node.getText() : null
            ));
        }

        return new StatusReport(
            "unknown",  // pluginId - unknown from Diagnostic
            Severity.fromValue(diagnostic.getSeverity()),
            diagnostic.getMessage(),
            diagnostic.getCode() == 0 ? null : diagnostic.getCode(),
            null,
            locations,
            children,
            (Exception) exception
        );
    }

    /**
     * Converts an IStatus to a StatusReport.
     * If the IStatus is already an instance of StatusReport, it is returned as-is.
     * Otherwise, a new StatusReport is created from the IStatus data.
     *
     * @param status the IStatus to convert
     * @return a StatusReport based on the IStatus, or null if status is null
     */
    public static StatusReport fromIStatus(IStatus status) {
        if (status == null) {
            return null;
        }
        
        // If already a StatusReport, return it directly
        if (status instanceof StatusReport statusReport) {
            return statusReport;
        }
        
        // Convert IStatus to StatusReport
        List<StatusReport> children = null;
        var statusChildren = status.getChildren();
        if (statusChildren != null && statusChildren.length > 0) {
            children = new ArrayList<>();
            for (var child : statusChildren) {
                var childReport = fromIStatus(child);
                if (childReport != null) {
                    children.add(childReport);
                }
            }
            if (children.isEmpty()) {
                children = null;
            }
        }
        
        return new StatusReport(
            status.getPlugin(),  // pluginId
            Severity.fromValue(status.getSeverity()),
            status.getMessage(),
            status.getCode() == 0 ? null : status.getCode(),
            null,  // details - not available from IStatus
            null,  // locations - not available from IStatus
            children,
            (Exception) status.getException()
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

	public static StatusReport okReport(String errorMessage, List<StatusReport> children) {
		return fromMessage(Severity.OK, errorMessage, children);
	}
	
	

	private static StatusReport fromMessage(Severity severity, String errorMessage, List<StatusReport> children) {
		return new StatusReport(
			null,  // pluginId - unknown
			severity,
			errorMessage,
			null,  // code - default
			null,  // details - none
			null,  // locations - unknown
			children,
			null   // exception - none
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
                    return resource.getURI().path();
                }
            } else if (firstData instanceof Resource resource) {
                return resource.getURI().path();
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
		
		// Process cause as child (if exists)
		var allChildren = new ArrayList<StatusReport>();
		if (children != null) {
			allChildren.addAll(children);
		}
		var cause = exception.getCause();
		if (cause != null) {
			var childReport = fromException(cause, null, null, seenExceptions);
			if (childReport != null) {
				allChildren.add(childReport);
			}
		}
		
		// Create StatusReport with defaults for unknown fields
		// Details will be filled automatically from exception if not provided
		var message = new StringBuffer();
		if (userMessage != null && !userMessage.isEmpty()) {
			message.append(userMessage).append("\n");
		}
		message.append(exception.getLocalizedMessage() != null ? exception.getLocalizedMessage() : exception.getClass().getSimpleName());
		return new StatusReport(
			null,  // pluginId - unknown
			Severity.ERROR,
			message.toString(),
			null,     // code - default
			null,     // details - will be filled from exception automatically
			null,     // locations - unknown
			allChildren,
			(Exception) exception  // pass the exception to StatusReport
		);
	}

}

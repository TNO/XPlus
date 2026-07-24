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

import java.util.List;
import java.util.Optional;

import org.eclipse.core.runtime.IStatus;

/**
 * A class for status reporting that represents the outcome of some processing
 * activity, implementing {@link IStatus} and serializable with Gson.
 */
public final class StatusReport implements IStatus {

	private String pluginId;
	private final int code;
	private final String message;
	private final Severity severity;
	private final String details;
	private final List<Location> locations; // Supports multiple sources for one status message
	private final List<StatusReport> children;
	private transient final Exception exception; // covered by details, not serialized

	/**
	 * Creates a new StatusReport with all fields including exception.
	 * 
	 * The severity field will be automatically elevated to the highest severity
	 * found in the children list, ensuring that the parent always reflects the most
	 * severe condition among its children.
	 *
	 * @param pluginId  the plugin identifier for this status
	 * @param severity  the initial severity level (will be elevated if children
	 *                  have higher severity)
	 * @param message   the message describing the situation
	 * @param code      the source-specific identity code
	 * @param details   the details string (representing low-level exception
	 *                  information)
	 * @param locations the list of location information (source, line numbers,
	 *                  offsets, text). Explicit multiplicity because one status can
	 *                  visible of multiple sources
	 * @param children  the list of child validation messages (severity will be
	 *                  elevated based on these)
	 * @param exception the exception associated with this status (transient, not
	 *                  serialized)
	 */
	public StatusReport(String pluginId, Severity severity, String message, Integer code, String details,
			List<Location> locations, List<StatusReport> children, Exception exception) {
		this.pluginId = pluginId;
		this.code = code != null ? code : 0;
		this.message = message;
		this.exception = exception;

		// If details is null but exception is not null, generate stack trace string
		var effectiveDetails = details == null && exception != null ? getStackTraceAsString(exception) : details;

		// Calculate the highest severity from children using streams
		var effectiveSeverity = children != null
				? children.stream().filter(child -> child != null).map(child -> child.severity)
						.filter(s -> s.value > severity.value).max((s1, s2) -> Integer.compare(s1.value, s2.value))
						.orElse(severity)
				: severity;

		this.severity = effectiveSeverity;
		this.details = effectiveDetails;
		this.locations = (locations != null && !locations.isEmpty()) ? locations : null;
		this.children = (children != null && !children.isEmpty()) ? children : null;
	}

	// IStatus implementation methods

	@Override
	public IStatus[] getChildren() {
		return children != null ? children.toArray(new IStatus[0]) : new IStatus[0];
	}

	@Override
	public int getCode() {
		return code;
	}

	@Override
	public Throwable getException() {
		return exception;
	}

	@Override
	public String getMessage() {
		return message;
	}

	@Override
	public String getPlugin() {
		return pluginId;
	}

	public void setPluginId(String pluginId) {
		this.pluginId = pluginId;
	}

	@Override
	public int getSeverity() {
		return mapSeverityToEclipse(severity);
	}

	@Override
	public boolean isMultiStatus() {
		return children != null && !children.isEmpty();
	}

	@Override
	public boolean isOK() {
		return severity == Severity.OK;
	}

	@Override
	public boolean matches(int severityMask) {
		return (getSeverity() & severityMask) != 0;
	}

	// Custom getter methods

	/**
	 * Gets the severity level of this report.
	 *
	 * @return the severity level
	 */
	public Severity getSeverityLevel() {
		return severity;
	}

	/**
	 * Gets the list of location information for this status report.
	 * 
	 * A single status message can refer to multiple sources, which is why this
	 * returns a list of locations. Each location contains source information such as
	 * file paths, line numbers, and offsets.
	 *
	 * @return an Optional containing the list of locations, or empty if no
	 *         locations
	 */
	public Optional<List<Location>> getLocations() {
		return Optional.ofNullable(locations);
	}

	/**
	 * Gets the details string (low-level exception information).
	 *
	 * @return an Optional containing the details, or empty if no details
	 */
	public Optional<String> getDetails() {
		return Optional.ofNullable(details);
	}

	/**
	 * Gets the list of child status reports.
	 *
	 * @return an Optional containing the children list, or empty if no children
	 */
	public Optional<List<StatusReport>> getChildReports() {
		return Optional.ofNullable(children);
	}

	/**
	 * Gets the plugin identifier for this status.
	 *
	 * @return an Optional containing the plugin ID, or empty if not set
	 */
	public Optional<String> getPluginId() {
		return Optional.ofNullable(pluginId);
	}

	/**
	 * Gets the exception associated with this status. This field is transient and
	 * will not be serialized.
	 *
	 * @return an Optional containing the exception, or empty if none
	 */
	public Optional<Exception> getExceptionOptional() {
		return Optional.ofNullable(exception);
	}

	/**
	 * Returns a string representation of the severity level.
	 *
	 * @return a string describing the severity
	 */
	public String getSeverityString() {
		return severity.name();
	}

	/**
	 * Checks if this report indicates an error condition.
	 *
	 * @return true if severity is ERROR or CANCEL, false otherwise
	 */
	public boolean isError() {
		return severity.isError();
	}

	/**
	 * Converts an exception's stack trace to a string representation. Limits the
	 * stack trace to 15 elements using Java 21+ features.
	 *
	 * @param exception the exception to convert
	 * @return a string representation of the stack trace
	 */
	private static String getStackTraceAsString(Exception exception) {
		if (exception == null) {
			return null;
		}

		var sb = new StringBuilder();
		sb.append(exception.getClass().getName());

		// Use Optional for null-safe message appending
		Optional.ofNullable(exception.getMessage()).ifPresentOrElse(msg -> sb.append(": ").append(msg), () -> {
		});

		sb.append("\n");

		// Use array stream for stack trace processing
		var stackTrace = exception.getStackTrace();
		var limit = Math.min(stackTrace.length, 15);

		for (int i = 0; i < limit; i++) {
			sb.append("\tat ").append(stackTrace[i]).append("\n");
		}

		if (stackTrace.length > 15) {
			sb.append("\t... ").append(stackTrace.length - 15).append(" more\n");
		}

		return sb.toString();
	}

	/**
	 * Maps a Severity enum value to Eclipse Status severity constants using pattern
	 * matching.
	 */
	private static int mapSeverityToEclipse(Severity severity) {
		return severity == null ? IStatus.OK : switch (severity) {
		case OK -> IStatus.OK;
		case INFO -> IStatus.INFO;
		case WARNING -> IStatus.WARNING;
		case ERROR -> IStatus.ERROR;
		case CANCEL -> IStatus.CANCEL;
		};
	}

	@Override
	public String toString() {
		return "StatusReport [pluginId=" + pluginId + ", code=" + code + ", message=" + message + ", severity="
				+ severity + ", details=" + details + ", locations=" + locations + ", children=" + children + "]";
	}

}
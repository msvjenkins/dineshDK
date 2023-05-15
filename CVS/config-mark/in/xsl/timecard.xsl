<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/">
<table data-role="table" id="ws_timecard-table" data-mode="reflow" class="ui-responsive table-stroke">
	<!--<thead style="background-color:grey;">
    <tr>
	  <th data-priority="9"  class="work_date" style="display:none">Date</th>
      <th data-priority="1">From</th>
	  <th data-priority="3">Allocated to</th>
      <th data-priority="5" class="jo_sl">Job Order</th>
      <th data-priority="6" class="task_sl">Task</th>
      <th data-priority="8" class="service_call_sl">Call</th>
	  <th data-priority="7"> </th>
    </tr>
  </thead>-->
  <tbody id="ws_timecard_body">
	<xsl:for-each select="list/timecard_entry">
		<tr>
		<td class="work_date" style="display:none"><xsl:value-of select="work_date"/></td>
		<td><xsl:value-of select="start_hour"/>:<xsl:value-of select="start_minute"/> - <xsl:value-of select="finish_hour"/>:<xsl:value-of select="finish_minute"/></td>
		<!--<td><xsl:value-of select="timespent_in_minutes"/></td>-->
		<xsl:choose>
		<xsl:when test="alloc_to_type_code = ''">
			<td></td>
		</xsl:when>		
		<xsl:otherwise>
		<td><xsl:value-of select="alloc_to_type_code"/></td>
		</xsl:otherwise>
		</xsl:choose>
		
		<xsl:choose>
		<xsl:when test="project_id = ''">
			<td class="jo_sl"></td>
		</xsl:when>		
		<xsl:otherwise>
			<td class="jo_sl"><xsl:value-of select="project_id"/></td>
		</xsl:otherwise>
		</xsl:choose>
		
		<xsl:choose>
		<xsl:when test="task_id = '0'">
			<td class="task_sl"></td>
		</xsl:when>
		<xsl:otherwise>
			<td class="task_sl"><xsl:value-of select="task_id"/></td>
		</xsl:otherwise>
		</xsl:choose>
		
		<xsl:choose>
		<xsl:when test="call_ref_no = ''">
			<td class="service_call_sl"></td>
		</xsl:when>
		<xsl:otherwise>
			<td class="service_call_sl"><xsl:value-of select="call_ref_no"/></td>
		</xsl:otherwise>
		</xsl:choose>
		<td><img src="../images/delete_button.png" class="timecard_delete" style="float:right;"></img></td>
		</tr>
	</xsl:for-each>
	</tbody>
</table>
</xsl:template>
</xsl:stylesheet>
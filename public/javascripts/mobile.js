$(document).ready(function() 
    { 
	var current_page = $("#page_select").attr('current_page');
        $("#page_select").val(current_page);
	$("#page_select").change(function() {
	    $('#page_selector').submit();
	});
    } 
); 

$(document).ready(function() 
    { 
	var current_page = $("#facet_select").attr('current_page');
	var source = $("#facet_select").attr('data-source');
        $("#facet_select").val(current_page);
	$("#facet_select").change(function() {
	    $('#search_facet_selector').val("true");
	    $('#search_'+source).submit();
	});
    } 
); 

$(document).ready(function() 
    { 
	$('#rightbutton a').click(function() 
				  { 
				      scroll(0,0);
				      return false;
				  });
    });

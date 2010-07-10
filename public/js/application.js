// Bart Jedrocha - 2009
// FluidMedia Inc.

/* Application wide
----------------------------------------------------------*/
$(function() {
	// on document ready
});

/* end Application wide
----------------------------------------------------------*/


/* Clients
----------------------------------------------------------*/

// POST /clients
function createClient() {
	$('input#client_create_submit').click(function(event) {
		event.preventDefault();
		$.ajax({
			url: '/clients',
			type: 'POST',
			dataType: 'html',
			data: $('form#client_create_form').serialize(),
			success: function(data) {
				$('#client_table').append(data);
				$('form#client_create_form').clearForm();
				showSuccess("Client successfully created");
			},
			error: function(error) {
				$('#info_area').html(error.responseText);
			}
		});
	});
}


// PUT /clients/:id
function updateClient(clientId) {
	$('input#client_edit_submit').click(function(event) {
		event.preventDefault();
		$.ajax({
			url: '/clients/' + clientId,
			type: 'PUT',
			dataType: 'html',
			data: $('form#client_edit_form').serialize(),
			success: function(data) {
				replaceClientDetails(data, clientId);
			},
			error: function(error) {
				$('#info_area').html(error.responseText);
			}
		});
	});
}

// custom callback function used by updateClient
function replaceClientDetails(data, clientId) {
	$('tr#client_'+clientId).replaceWith(data);
	$('form#client_edit_form').clearForm();
	showSuccess("Client successfully updated.");
}

// GET /cients/id
function showClient(clientId) {
	$.ajax({
		url: '/clients/'+clientId,
		type: 'GET',
		dataType: 'html',
		success: function(data) {
			$('#client_details').html(data);
			$('#client_details').slideDown('fast');
		}
	});
	return false;
}

// GET /clients/new
function newClient() {
	$.ajax({
		url: '/clients/new',
		type: 'GET',
		dataType: 'html',
		success: function(data) {
			$('#client_form').html(data);
			$('#client_form').slideDown('fast');
			createClient();
		}
	});
	return false;
}

// GET /clients/id/edit
function editClient(clientId) {
	$.ajax({
		url: '/clients/' + clientId + '/edit',
		type: 'GET',
		dataType: 'html',
		success: function(data) {
			$('#client_form').html(data);
			$('#client_form').slideDown('fast');
			updateClient(clientId);
		}
	});
	return false;
}

// DELETE /clients/id
function deleteClient(clientId) {
	if(confirm("Are you sure?")) {
		$.ajax({
	      url: '/clients/' + clientId,
	      type: 'DELETE',
	      dataType: 'html',
	      success: function(data) {
					removeClientDetails(data, clientId);
	      },
	  });
	}
	return false;
}

// callback function to remove a client row from the DOM
function removeClientDetails(data, clientId) {
	$('tr#client_'+clientId).remove();
	showSuccess("Client successfully removed.");
}

/* end Clients
----------------------------------------------------------*/


/* UI functions
----------------------------------------------------------*/
function showErrors(message, errors) {
	var html = "<div id='validation_errors' class='validation'>";
	html += message + "</br>";
	html += "<ul>";
	jQuery.each(errors, function(){
		html += "<li>" + this + "</li>";
	});
	html += "</ul>";
	$('#info_area').html(html);
}

function showSuccess(message) {
	var html = "<div id='success_message' class='success'>" + message;
	$('#info_area').html(html);
	$('#success_message').idle(2000).fadeOut('slow');
}

/* FancyBox Video Player
----------------------------------------------------------*/
function getFancy(encodingId) {
	$('#encoding_' + encodingId).fancybox({
		'hideOnContentClick':false
	});
}

/* jQuery Extensions
----------------------------------------------------------*/
$.fn.clearForm = function() {
  return this.each(function() {
    var type = this.type, tag = this.tagName.toLowerCase();
    if (tag == 'form')
      return $(':input',this).clearForm();
    if (type == 'text' || type == 'password' || tag == 'textarea')
      this.value = '';
    else if (type == 'checkbox' || type == 'radio')
      this.checked = false;
    else if (tag == 'select')
      this.selectedIndex = -1;
  });
};

$.fn.exists = function() { 
	return (this.length > 0); 
};

$.fn.hideElement = function() {
	this.slideUp('fast');
};

// Helper function for delaying a function call
$.fn.idle = function(time) {
	var o = $(this);
  o.queue(function() {
	  setTimeout(function() {
	  	o.dequeue();
	  }, time);
  });
	return this;
};
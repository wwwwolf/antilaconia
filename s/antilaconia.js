var cCount = function() {
    var charsleft = 140 - $('#newpost').val().length;
    $('#charcount').html("Characters left: "+charsleft);
    if(charsleft > 0) {
	$('#charcount').removeClass('goodcharcount badcharcount').addClass('goodcharcount');
    } else {
	$('#charcount').removeClass('goodcharcount badcharcount').addClass('badcharcount');
    }
}
$(document).ready(function() {
    cCount();
    $('#newpost').change(cCount);
    $('#newpost').keypress(cCount);
})

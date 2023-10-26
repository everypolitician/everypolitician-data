jQuery(function($) {

  var button = function(text) { 
    return $('<button style="margin:2px">' + text + '</button>').click(function (e) { 
      var id = $(this).closest('p').hide().attr('data-id');mfgb,
      $("#results").append(id + "," + text + "\n")
    }) 
  };

  $("div#data p").html(function(i,text) { 
    return '<a href="https://www.wikidata.org/wiki/' + $(this).attr('data-id') + '">' + text + '</a>'
  });

  $("div#data p").prepend(button("Exclude"));
  $("div#data p").prepend(button("Other"));
  $("div#data p").prepend(button("Party"));
  $("div#data p").prepend(button("Other Executive"));
  $("div#data p").prepend(button("Cabinet"));
  $("div#data p").prepend(button("Other Legislature"));
  $("div#data p").prepend(button("Self (keep)"));
  $("div#data p").prepend(button("Self (skip)"));
});

  $(document).ready(function()
  {
     if (window.WebSocket) {
        $("#realtimeUpdate").show();
        $("#realtimeUpdate").click(function(event)
        {
            if ($("#realtimeUpdate").attr("value") == "Start realtime update") {
              webSocket.connect();
            } else {
              webSocket.close();
            }
        });
      }
      else {
        $("realtimeUpdate").hide();
      }
  
      $("#clear-logs").click(function(event){
         $("#messageLog").empty();
         $("#callflow").empty();
         doAction(this);         
         event.preventDefault();
      });
            
       setFilterClickEvents();
   });
   
  function setFilterClickEvents()
  {
      $(".filter").click(function(event){
         refresh(this.href);
         event.preventDefault();
      });
      
      $("#filterForm input").click(function(event){
         var uri = document.location.toString();
         if (uri.indexOf("#") > 0)
            uri = uri.substr(0, uri.indexOf("#"));
         uri += "?" + $("#filterForm").serialize();
         refresh(uri);
         event.preventDefault();
      });
  }
   
  function refresh(target)
  {
    $.getJSON(target, {ajax: "true", action: "refresh-logs"}, function(data){
        var items = [];

       $.each(data, function(key, val) {
          $("#" + key).replaceWith(val);
       });
        
        refreshGraph();
        setFilterClickEvents();
     });
  }
  
  function doAction(event)
  {
    $.get(document.location, { ajax: "true", action: event.id } );
  }
  
  
  function log(message)
  {
    var log = $("#messageLog");
    
    log.append("<a/>");
    log.append("<div>" + message + "</div>");
        
    var maxMessages = $("#maxMessages").val();
    var childCount = $("#messageLog div").size() / 2;
    while (childCount > maxMessages)
    {
        $("#messageLog:first-child").remove();
        childCount = $("#messageLog div").size() / 2;
    }
    
    var children = log.children("A");
    children.attr("name", function(i, val) {
        return 'msg-' + i;
    });
    
    refreshGraph();  
    setFilterClickEvents();
  }
  
  function refreshGraph()
  {
    var childCount = $("#messageLog div").size() / 2;
    var height = 100 + (childCount * 25);

    var html = '<embed height="' + height;
    html = html +  '" width="790" pluginspage="http://www.adobe.com/svg/viewer/install/" type="image/svg+xml" src="message.svg">';
    $("#callflow").html(html);
  }
  
    
  var webSocket = {

    connect: function() {
      var location = document.location.toString().replace('http:','ws:');
      var location = location.replace('logs-sip','ws-logs');
      this._ws = new WebSocket(location);
      this._ws.onopen = this._onopen;
      this._ws.onmessage = this._onmessage;
      this._ws.onerror = this._onerror;
      this._ws.onclose = this._onclose;
    },

    _onopen: function() {
      $("#realtimeUpdate").attr("value", "Stop realtime update");
    },

    send: function(message) {
      if (this._ws) {
        this._ws.send(message);
        log(message);
      }
    },

    _onmessage: function(m) {
      if (m.data) {
        log(m.data);
      }
    },

    _onerror: function(m) {
      if (m.data) {
        log("error: " + m.data);
      }
    },

    _onclose: function(m) {
      this._ws = null;
      $("#realtimeUpdate").attr("value", "Start realtime update");
    },

    close: function() {
      if (this._ws) {
        this._ws.close();
      }
    }

  };
  
  
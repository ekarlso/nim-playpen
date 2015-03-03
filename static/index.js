var editor = ace.edit("editor");

editor.setTheme("ace/theme/monokai");
//editor.getSession().setMode("ace/mode/javascript");
editor.setOption("newLineMode", "unix");

$("button#run").on("click", function(e) {
    var version = $("select#version option:selected").text() || "devel";
    var input = editor.getSession().getValue().replace("\n", "\r");

    var data = JSON.stringify({input: input, version: version})
    $.ajax({
        url: "/runs",
        type: "post",
        dataType: "json",
        contentType: 'application/json',
        data: data,
        processData: false,
        success: function( data ) {
            $("#result").html(data.result);
            $("#output").html(data.output);

            console.log(data)
        }
    })
})
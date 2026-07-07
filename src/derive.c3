module derive;

macro derive(String $typename, ...) @const @builtin @weak {
  var $out = "";
  $for int $i = 0; $i < $vaarg.len; $i++:
    $out +++= $eval($stringify($vaarg[$i]))($typename);
  $endfor
  return $out;
}

macro seali(String $typename) @const {
  return @sprintf("fn void? %s.parse(&self, String[] args) => seali::impl_parse{%s}(self, args);\n", $typename, $typename);
}


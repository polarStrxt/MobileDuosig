import 'package:flutter/material.dart';

class Leia extends StatefulWidget {
  final String texto;
  final IconData icone;
  final TextEditingController dados;
  final bool isPassword; // 🔹 Adicionado para saber se é um campo de senha

  const Leia({
    required this.texto,
    required this.icone,
    required this.dados,
    this.isPassword = false, // 🔹 Por padrão, não é um campo de senha
    Key? key,
  }) : super(key: key);

  @override
  _LeiaState createState() => _LeiaState();
}

class _LeiaState extends State<Leia> {
  bool _obscureText = true; // 🔹 Controla a visibilidade da senha

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: TextField(
        controller: widget.dados,
        obscureText: widget.isPassword ? _obscureText : false, // 🔹 Oculta senha se necessário
        style: TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: widget.texto,
          labelStyle: TextStyle(fontSize: 14, color: Colors.blueGrey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.blueGrey, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.blueGrey, width: 2.0),
          ),
          prefixIcon: Icon(widget.icone, color: Colors.blueGrey),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          // 🔹 Ícone para mostrar/ocultar senha
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                  color: Colors.blueGrey,
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}

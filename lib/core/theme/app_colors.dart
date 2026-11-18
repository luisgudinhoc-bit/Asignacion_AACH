import 'package:flutter/material.dart';

/// Paleta de colores optimizada para Material 3 y trabajo de campo
class AppColors {
  // Primarios y de acento
  static const Color primary = Color(0xFF1E3A8A); // Azul Marino Operativo
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF172554);
  static const Color secondary = Color(0xFF0D9488); // Teal Técnico
  static const Color accent = Color(0xFFF59E0B); // Ámbar de Alerta

  // Estatus Operativos
  static const Color statusAsignado = Color(0xFFF59E0B); // Amarillo / Ámbar
  static const Color statusEnAtencion = Color(0xFF2563EB); // Azul Eléctrico
  static const Color statusConcluido = Color(0xFF10B981); // Verde Éxito
  static const Color statusCancelado = Color(0xFFEF4444); // Rojo Alerta

  // Fondos y Superficies
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);

  // Textos y Bordes
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);

  // WhatsApp Brand Color
  static const Color whatsappGreen = Color(0xFF25D366);

  /// Obtiene un color identificador distintivo para cada aseguradora
  static Color getAseguradoraColor(String aseguradora) {
    switch (aseguradora.toLowerCase()) {
      case 'quálitas':
      case 'qualitas':
        return const Color(0xFF8B5CF6); // Púrpura Quálitas
      case 'gnp seguros':
      case 'gnp':
        return const Color(0xFFEA580C); // Naranja GNP
      case 'inbursa':
        return const Color(0xFFDC2626); // Rojo Inbursa
      case 'axa seguros':
      case 'axa':
        return const Color(0xFF0284C7); // Azul Marino AXA
      case 'hdi seguros':
      case 'hdi':
        return const Color(0xFF16A34A); // Verde HDI
      case 'chubb seguros':
      case 'chubb':
        return const Color(0xFF0F766E); // Teal Chubb
      case 'mapfre':
        return const Color(0xFFB91C1C); // Guinda Mapfre
      case 'banorte':
        return const Color(0xFFC026D3); // Magenta Banorte
      default:
        return const Color(0xFF475569); // Gris neutro
    }
  }
}
